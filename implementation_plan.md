# RV32I 五级流水线改造为九级记分牌乱序执行处理器 — 实施计划

## Context

基于 `build.md` 的任务要求，需要将现有的 5 级顺序流水线处理器（IF→ID→EX→MEM→WB）改造为 9 级记分牌乱序执行处理器（IF→IS→RO→EX1→EX2→EX3→EX4→MEM→WB）。改造分两个任务：任务1将EX站扩展为4拍；任务2将ID站拆分为IS+RO并实现记分牌机制。

## 一、目标架构总览

```
原始:  IF → ID → EX → MEM → WB
目标:  IF → IS → RO → EX1 → EX2 → EX3 → EX4 → MEM → WB
```

核心变化：
- 删除数据前递（`forwarding.v`），指令总是从寄存器文件读取已写回的值
- 删除原有冒险检测（`hazard_detection.v`），由记分牌逻辑替代
- ID 拆分为 IS（流出/译码）+ RO（读操作数）
- EX 扩展为 EX1→EX2→EX3→EX4，仅 EX4 执行实际 ALU 运算
- 新增结果寄存器状态表和功能部件状态表

---

## 二、任务1：EX 站扩展为 4 拍

### 2.1 设计决策

- 在 EX4 执行实际 ALU 运算（EX1/EX2/EX3 仅打拍传递数据）
- 理由：EX4 输出直接进入 MEM，与原始 EX→MEM 接口一致，改动最小

### 2.2 新增文件

#### `reg_ex1_ex2.v`、`reg_ex2_ex3.v`、`reg_ex3_ex4.v`

三个结构相同的流水线寄存器模块，负责 EX 各子阶段之间的数据打拍传递。每个模块传递以下信号：

```
pc[31:0], regs_data1[31:0], regs_data2[31:0], imm[31:0],
func3_code[2:0], func7_code, rd[4:0], rs2[4:0],
alu_op[2:0], alu_src1[1:0], alu_src2[1:0],
mem_read, mem2reg, mem_write, regs_write,
fu_id[2:0]  // 新增：功能部件编号，用于WB时清除记分牌
```

逻辑：`posedge clk` 时，`!rst` 全部清零，否则逐信号传递。无 stall/flush。

### 2.3 修改文件

#### `stage_ex.v` — 改为 EX4 阶段执行

- 所有输入信号前缀 `ex_` → `ex4_`
- 删除前递相关端口和逻辑（`forwardA`, `forwardB`, `me_alu_o`, `w_regs_data`）
- 删除分支相关端口（`br_pc`, `br_ctrl`, `ex_br`, `ex_br_addr_mode`）
- `op_A_pre` / `op_B_pre` 直接使用寄存器数据：

```verilog
assign op_A_pre = ex4_regs_data1;
assign op_B_pre = ex4_regs_data2;
// op_A, op_B 的 alu_src 选择逻辑保持不变
```

#### `reg_ex_mem.v` — 输入前缀改为 `ex4_`

输入信号从 EX4 阶段的输出接收，前缀 `ex_` → `ex4_`。新增 `ex4_fu_id[2:0]` 传递到 MEM 阶段。

#### 删除 `forwarding.v` 和 `hazard_detection.v`

这两个模块在新架构中不再需要。

---

## 三、任务2：记分牌乱序执行

### 3.1 记分牌数据结构

#### 3.1.1 结果寄存器状态表（Result Register Status Table）

- 32 项，每项 3 位 `FU[2:0]`
- `3'b000` = 寄存器值有效（ready）
- `3'b001` ~ `3'b111` = 将由对应功能部件写入（1=ADD, 2=SUB, 3=AND, 4=OR, 5=XOR, 6=LW, 7=SW）
- 注：SW 不写寄存器，实际上 SW 的 rd 不会被标记，但 SW 占用 FU7

#### 3.1.2 功能部件状态表（Functional Unit Status Table）

7 个条目（索引 1~7），每个条目包含：

| 字段 | 位宽 | 说明 |
|------|------|------|
| `busy` | 1 | 该 FU 是否被占用 |
| `state` | 2 | 00=空闲, 01=等待操作数, 10=已进入RO（不可再选） |
| `inst` | 32 | 完整指令（供 imm_gen 使用） |
| `pc` | 32 | 指令 PC |
| `rd` | 5 | 目标寄存器 |
| `rs1` | 5 | 源寄存器1 |
| `rs2` | 5 | 源寄存器2 |
| `func3_code` | 3 | funct3 |
| `func7_code` | 1 | funct7 (bit30) |
| `alu_op` | 3 | ALU 操作类型 |
| `alu_src1` | 2 | ALU 操作数1来源 |
| `alu_src2` | 2 | ALU 操作数2来源 |
| `mem_read` | 1 | 读存储器 |
| `mem2reg` | 1 | 写回来源选择 |
| `mem_write` | 1 | 写存储器 |
| `regs_write` | 1 | 写寄存器 |

#### 3.1.3 功能部件编号映射

| 指令 | opcode | FU 编号 |
|------|--------|---------|
| ADD / ADDI / LUI / AUIPC | Rtype(R_ADD) / ItypeA / UtypeL / UtypeU | 1 |
| SUB | Rtype(R_SUB) | 2 |
| AND | Rtype(R_AND) | 3 |
| OR | Rtype(R_OR) | 4 |
| XOR | Rtype(R_XOR) | 5 |
| LW | ItypeL | 6 |
| SW | Stype | 7 |

### 3.2 IS（流出）站 — 新模块 `stage_is.v`

IS 站职责：译码、确定功能部件编号、检查流出条件。

#### 输入

```verilog
input wire[31:0]  is_inst,          // 来自 reg_if_is
input wire[31:0]  is_pc,            // 来自 reg_if_is
input wire[2:0]   reg_status[0:31], // 结果寄存器状态表（外部模块提供）
input wire[6:0]   fu_busy,          // 功能部件忙标志（7位，bit0=FU1...bit6=FU7）
```

#### 输出

```verilog
output wire[2:0]  is_fu_id,         // 分配的功能部件编号 (1~7, 0=无效)
output wire       is_can_issue,     // 是否可以流出
output wire       is_stall,         // IF和IS需要停顿
// 透传到功能部件状态表的控制信号
output wire[4:0]  is_rd, is_rs1, is_rs2,
output wire[2:0]  is_func3_code, is_alu_op,
output wire       is_func7_code,
output wire[1:0]  is_alu_src1, is_alu_src2,
output wire       is_mem_read, is_mem2reg, is_mem_write, is_regs_write
```

#### 核心逻辑

1. 复用 `ctrl.v` 译码生成控制信号
2. 根据 opcode + func3 + func7 确定 `fu_id[2:0]`（映射表见 3.1.3）
3. 流出条件判断：

```verilog
// 指令有效（非NOP）
wire is_valid = (is_inst != 32'b0) && (fu_id != 3'd0);
// 目标FU空闲
wire fu_free = !fu_busy[fu_id - 1];
// WAW检查：如果指令要写rd，则rd当前必须是ready的（reg_status[rd]==0）
// 或者rd==0（x0不可写，无需检查）
wire no_waw = !is_regs_write || (is_rd == 5'd0) || (reg_status[is_rd] == 3'b000);
// 可以流出
assign is_can_issue = is_valid && fu_free && no_waw;
// 不能流出时停顿
assign is_stall = is_valid && !is_can_issue;
```

#### 流出时的副作用（在顶层连线）

当 `is_can_issue == 1` 时：
- 将指令信息写入功能部件状态表的 `fu_id` 条目
- 如果 `is_regs_write && is_rd != 0`，更新结果寄存器状态表：`reg_status[is_rd] = fu_id`

### 3.3 功能部件状态表中的操作数就绪判断与选择

指令流出后进入功能部件状态表，`state=01`（等待操作数）。每个周期，对所有 `state==01` 的条目检查操作数就绪性：

```verilog
// 对于 FU 条目 i (0~6，对应 FU 1~7):
wire src1_ready_i = (entry_alu_src1[i] == `NULL) ||
                    (entry_alu_src1[i] == `PC) ||
                    (entry_rs1[i] == 5'd0) ||
                    (reg_status[entry_rs1[i]] == 3'b000);

wire src2_ready_i = (entry_alu_src2[i] == `IMM) ||
                    (entry_alu_src2[i] == `PC_PLUS4) ||
                    (entry_rs2[i] == 5'd0) ||
                    (reg_status[entry_rs2[i]] == 3'b000);

// SW 指令需要 rs2 的值作为存储数据，也需要检查 rs2 就绪
wire operands_ready_i = src1_ready_i && src2_ready_i;
wire can_select_i = entry_valid[i] && (entry_state[i] == 2'b01) && operands_ready_i;
```

选择算法：从 `can_select` 为真的条目中选择一条（固定优先级，FU1 > FU2 > ... > FU7，即选择编号最小的就绪指令）。

被选中的指令：
- `state` 从 `01` 变为 `10`（已进入 RO，不可再选）
- 指令信息输出到 RO 站

### 3.4 RO（读操作数）站 — 新模块 `stage_ro.v`

RO 站职责：从寄存器文件读取操作数、生成立即数。

```verilog
module stage_ro(
    input  wire        clk, rst,
    // 从功能部件状态表选出的指令信息
    input  wire[31:0]  ro_inst, ro_pc,
    input  wire[4:0]   ro_rs1, ro_rs2,
    // 寄存器文件写回端口（来自 WB）
    input  wire        w_regs_en,
    input  wire[4:0]   w_regs_addr,
    input  wire[31:0]  w_regs_data,
    // 输出
    output wire[31:0]  ro_regs_data1, ro_regs_data2, ro_imm
);
```

内部实例化：
- `regs.v`：读取 `ro_rs1` 和 `ro_rs2` 对应的寄存器值
- `imm_gen.v`：根据 `ro_inst` 生成立即数

注意：`regs.v` 的写端口连接 WB 站的写回信号，与原始设计相同。`regs.v` 内部已有写回前递逻辑（同周期读写同一寄存器时前递写入值）。

### 3.5 新模块 `reg_status_table.v` — 结果寄存器状态表

```verilog
module reg_status_table(
    input  wire        clk, rst,
    // IS 写入：指令流出时标记 rd
    input  wire        is_write_en,    // is_can_issue && is_regs_write && is_rd!=0
    input  wire[4:0]   is_rd,
    input  wire[2:0]   is_fu_id,
    // WB 清除：指令写回时清除标记
    input  wire        wb_clear_en,    // wb_regs_write
    input  wire[4:0]   wb_rd,
    input  wire[2:0]   wb_fu_id,
    // 查询端口（组合逻辑输出）
    output wire[2:0]   status [0:31]   // 全部32项供外部查询
);
```

更新逻辑（`posedge clk`）：
- WB 清除：若 `wb_clear_en && wb_rd!=0 && status[wb_rd]==wb_fu_id`，则 `status[wb_rd] <= 3'b000`
- IS 写入：若 `is_write_en`，则 `status[is_rd] <= is_fu_id`
- 同一周期同一寄存器的 WB 清除和 IS 写入冲突时，IS 写入优先（Verilog always 块中后赋值覆盖前赋值）

### 3.6 新模块 `fu_status_table.v` — 功能部件状态表

这是记分牌的核心模块，集成了指令缓存、操作数就绪判断和选择逻辑。

#### 端口

```verilog
module fu_status_table(
    input  wire        clk, rst,
    // IS 写入
    input  wire        is_write_en,     // is_can_issue
    input  wire[2:0]   is_fu_id,        // 写入哪个 FU (1~7)
    input  wire[31:0]  is_inst, is_pc,
    input  wire[4:0]   is_rd, is_rs1, is_rs2,
    input  wire[2:0]   is_func3_code, is_alu_op,
    input  wire        is_func7_code,
    input  wire[1:0]   is_alu_src1, is_alu_src2,
    input  wire        is_mem_read, is_mem2reg, is_mem_write, is_regs_write,
    // 结果寄存器状态表查询（用于判断操作数就绪）
    input  wire[2:0]   reg_status [0:31],
    // WB 清除
    input  wire        wb_clear_en,
    input  wire[2:0]   wb_fu_id,
    // RO 选择输出
    output wire        ro_valid,         // 有指令被选中
    output wire[2:0]   ro_fu_id,
    output reg [31:0]  ro_inst, ro_pc,
    output reg [4:0]   ro_rd, ro_rs1, ro_rs2,
    output reg [2:0]   ro_func3_code, ro_alu_op,
    output reg         ro_func7_code,
    output reg [1:0]   ro_alu_src1, ro_alu_src2,
    output reg         ro_mem_read, ro_mem2reg, ro_mem_write, ro_regs_write,
    // 状态查询
    output wire[6:0]   fu_busy          // 每位表示对应 FU 是否被占用
);
```

#### 内部存储

每个 FU 条目（共 7 个，索引 0~6 对应 FU 1~7）：

```verilog
reg        entry_busy   [0:6];   // 是否被占用
reg [1:0]  entry_state  [0:6];   // 00=空闲, 01=等待操作数, 10=已进入RO/EX流水线
reg [31:0] entry_inst   [0:6];
reg [31:0] entry_pc     [0:6];
reg [4:0]  entry_rd     [0:6];
reg [4:0]  entry_rs1    [0:6];
reg [4:0]  entry_rs2    [0:6];
reg [2:0]  entry_func3  [0:6];
reg        entry_func7  [0:6];
reg [2:0]  entry_alu_op [0:6];
reg [1:0]  entry_src1   [0:6];
reg [1:0]  entry_src2   [0:6];
reg        entry_mr     [0:6];   // mem_read
reg        entry_m2r    [0:6];   // mem2reg
reg        entry_mw     [0:6];   // mem_write
reg        entry_rw     [0:6];   // regs_write
```

#### 操作数就绪判断（组合逻辑）

```verilog
wire can_select [0:6];
genvar g;
generate
    for (g = 0; g < 7; g = g + 1) begin : ready_check
        wire s1_rdy = (entry_src1[g] == `NULL) || (entry_src1[g] == `PC) ||
                      (entry_rs1[g] == 5'd0) || (reg_status[entry_rs1[g]] == 3'b000);
        wire s2_rdy = (entry_src2[g] == `IMM) || (entry_src2[g] == `PC_PLUS4) ||
                      (entry_rs2[g] == 5'd0) || (reg_status[entry_rs2[g]] == 3'b000);
        assign can_select[g] = entry_busy[g] && (entry_state[g] == 2'b01) && s1_rdy && s2_rdy;
    end
endgenerate
```

#### 选择逻辑（固定优先级，FU1 优先）

```verilog
wire [2:0] sel_idx;  // 被选中的条目索引 (0~6)
wire       sel_valid;
assign sel_valid = can_select[0] || can_select[1] || can_select[2] ||
                   can_select[3] || can_select[4] || can_select[5] || can_select[6];
assign sel_idx   = can_select[0] ? 3'd0 :
                   can_select[1] ? 3'd1 :
                   can_select[2] ? 3'd2 :
                   can_select[3] ? 3'd3 :
                   can_select[4] ? 3'd4 :
                   can_select[5] ? 3'd5 :
                   can_select[6] ? 3'd6 : 3'd0;
assign ro_valid  = sel_valid;
assign ro_fu_id  = sel_idx + 3'd1;  // FU 编号 = 索引 + 1
```

#### 状态转换逻辑（`posedge clk`）

```
IS 写入:  entry_busy=1, entry_state=01（等待操作数）
RO 选中:  entry_state 从 01 → 10（已进入流水线，防止重复选择）
WB 清除:  entry_busy=0, entry_state=00（释放 FU）
```

关键：被选中进入 RO 的指令，在 WB 写回之前一直保持 `state=10`、`busy=1`，因此不会被再次选中。WB 写回时通过 `wb_fu_id` 定位条目并清除。

#### `fu_busy` 输出

```verilog
assign fu_busy = {entry_busy[6], entry_busy[5], entry_busy[4],
                  entry_busy[3], entry_busy[2], entry_busy[1], entry_busy[0]};
```

---

## 四、流水线寄存器变更总结

### 4.1 `reg_if_id.v` → 改为 `reg_if_is.v`

- 输出前缀 `id_` → `is_`：`is_inst[31:0]`, `is_pc[31:0]`
- 保留 stall 功能（`if_is_stall`），当 IS 站不能流出时停顿
- 保留 flush 功能（`if_is_flush`），预留分支清除（当前测试不含分支，可简化）

### 4.2 新增 `reg_ro_ex1.v`（替代原 `reg_id_ex.v`）

RO→EX1 的流水线寄存器。传递信号：

```
ro_pc, ro_regs_data1, ro_regs_data2, ro_imm,
ro_func3_code, ro_func7_code, ro_rd, ro_rs2,
ro_alu_op, ro_alu_src1, ro_alu_src2,
ro_mem_read, ro_mem2reg, ro_mem_write, ro_regs_write,
ro_fu_id[2:0],   // 功能部件编号
ro_valid          // 是否有有效指令
```

输出前缀 `ex1_`。当 `ro_valid == 0` 时，输出全部清零（相当于插入气泡）。

### 4.3 `reg_ex1_ex2.v` / `reg_ex2_ex3.v` / `reg_ex3_ex4.v`

见第二节 2.2，纯打拍传递，包含 `fu_id` 和 `valid` 信号。

### 4.4 `reg_ex_mem.v` — 修改

- 输入前缀 `ex_` → `ex4_`
- 新增 `fu_id[2:0]` 传递
- 删除 `ex_rs2`（不再需要 store forwarding）

### 4.5 `reg_mem_wb.v` — 修改

- 新增 `fu_id[2:0]` 传递到 WB 站，用于清除记分牌

---

## 五、WB 站和 MEM 站修改

### 5.1 `stage_wb.v` — 修改

在原有写回选择逻辑基础上，WB 站需要在写回寄存器的同时触发记分牌清除：

- 输出 `wb_fu_id[2:0]`（从 `reg_mem_wb` 传递而来）
- 输出 `wb_regs_write`（已有）和 `wb_rd`（已有）
- 这些信号连接到 `reg_status_table` 和 `fu_status_table` 的 WB 清除端口

### 5.2 `stage_mem.v` — 修改

- 删除 store forwarding 逻辑（`forward_data` 输入和相关 mux）
- `w_data_mem` 直接使用 `me_regs_data2`（因为操作数在 RO 站已从寄存器文件正确读取）

---

## 六、顶层模块 `adam_riscv.v` 重新连线

### 6.1 信号流总览

```
IF:  stage_if → if_inst, if_pc
      ↓
     reg_if_is (stall: is_stall)
      ↓
IS:  stage_is → 译码, fu_id, can_issue
      ↓ (can_issue时写入)
     fu_status_table ← 指令信息
     reg_status_table ← 标记 rd
      ↓ (操作数就绪时选出)
     fu_status_table → ro_inst, ro_pc, ro_rs1, ro_rs2, ...
      ↓
RO:  stage_ro → ro_regs_data1, ro_regs_data2, ro_imm
      ↓
     reg_ro_ex1
      ↓
EX1: (打拍) → reg_ex1_ex2
EX2: (打拍) → reg_ex2_ex3
EX3: (打拍) → reg_ex3_ex4
      ↓
EX4: stage_ex → ex4_alu_o
      ↓
     reg_ex_mem
      ↓
MEM: stage_mem → me_mem_data
      ↓
     reg_mem_wb
      ↓
WB:  stage_wb → w_regs_data
     → 写回 regs (通过 stage_ro 的写端口)
     → 清除 reg_status_table
     → 清除 fu_status_table
```

### 6.2 停顿逻辑

```
pc_stall    = is_stall   (IS不能流出时，IF和IF/IS寄存器都停顿)
if_is_stall = is_stall
```

RO→EX1→EX2→EX3→EX4→MEM→WB 这条流水线不需要停顿（因为记分牌保证操作数就绪后才进入 RO，且 EX 各阶段等拍、无结构冒险）。当某周期功能部件状态表中没有操作数就绪的指令时，`ro_valid=0`，`reg_ro_ex1` 输出全零（气泡），自然传播到后续阶段。

---

## 七、文件变更总结

### 7.1 新增文件（`RVDesign/AdamRiscv/` 下）

| 文件 | 说明 |
|------|------|
| `stage_is.v` | IS（流出）站：译码 + FU 映射 + 流出判断 |
| `stage_ro.v` | RO（读操作数）站：读寄存器 + 生成立即数 |
| `reg_status_table.v` | 结果寄存器状态表（32项×3位） |
| `fu_status_table.v` | 功能部件状态表（7条目 + 选择逻辑） |
| `reg_if_is.v` | IF/IS 流水线寄存器（改自 `reg_if_id.v`） |
| `reg_ro_ex1.v` | RO/EX1 流水线寄存器（改自 `reg_id_ex.v`） |
| `reg_ex1_ex2.v` | EX1/EX2 流水线寄存器 |
| `reg_ex2_ex3.v` | EX2/EX3 流水线寄存器 |
| `reg_ex3_ex4.v` | EX3/EX4 流水线寄存器 |

### 7.2 修改文件

| 文件 | 修改内容 |
|------|----------|
| `adam_riscv.v` | 重写顶层连线，实例化所有新模块，删除旧模块实例 |
| `stage_ex.v` | 输入前缀改 `ex4_`，删除前递和分支逻辑 |
| `stage_mem.v` | 删除 store forwarding 逻辑 |
| `reg_ex_mem.v` | 输入前缀改 `ex4_`，新增 `fu_id` |
| `reg_mem_wb.v` | 新增 `fu_id` 传递 |
| `define.vh` | 新增 FU 编号宏定义 |
| `Makefile` | 更新 Verilog 源文件列表 |

### 7.3 删除文件

| 文件 | 原因 |
|------|------|
| `forwarding.v` | 不再使用数据前递 |
| `hazard_detection.v` | 由记分牌替代 |
| `reg_if_id.v` | 被 `reg_if_is.v` 替代 |
| `reg_id_ex.v` | 被 `reg_ro_ex1.v` 替代 |
| `stage_id.v` | 被 `stage_is.v` + `stage_ro.v` 替代 |

### 7.4 `Makefile` 修改

更新 Verilator 编译命令中的源文件列表，删除旧文件、添加新文件：

```makefile
$(VERILATOR) $(VERILATOR_FLAGS) \
    ./AdamRiscv/define.vh \
    ./AdamRiscv/adam_riscv.v \
    ./AdamRiscv/alu.v \
    ./AdamRiscv/alu_control.v \
    ./AdamRiscv/ctrl.v \
    ./AdamRiscv/data_memory.v \
    ./AdamRiscv/imm_gen.v \
    ./AdamRiscv/inst_memory.v \
    ./AdamRiscv/pc.v \
    ./AdamRiscv/regs.v \
    ./AdamRiscv/stage_if.v \
    ./AdamRiscv/stage_is.v \
    ./AdamRiscv/stage_ro.v \
    ./AdamRiscv/stage_ex.v \
    ./AdamRiscv/stage_mem.v \
    ./AdamRiscv/stage_wb.v \
    ./AdamRiscv/reg_if_is.v \
    ./AdamRiscv/reg_ro_ex1.v \
    ./AdamRiscv/reg_ex1_ex2.v \
    ./AdamRiscv/reg_ex2_ex3.v \
    ./AdamRiscv/reg_ex3_ex4.v \
    ./AdamRiscv/reg_ex_mem.v \
    ./AdamRiscv/reg_mem_wb.v \
    ./AdamRiscv/reg_status_table.v \
    ./AdamRiscv/fu_status_table.v \
    adam_riscv_main.cpp \
    --top-module adam_riscv
```

---

## 八、验证方案

### 8.1 测试用例1：执行延迟测试

使用 `build.md` 中的测试用例1，验证 ADD/SUB/AND/OR/XOR/LW/SW 在 4 拍 EX 下的正确执行。

预期行为：
- 初始化阶段（`li`, `la`）使用 ADDI/AUIPC 指令，走 ADD 功能部件
- NOP 序列确保初始化指令写回后再执行 main 段
- main 段的 7 条指令分别占用 7 个不同的 FU，无数据依赖，可全部流出
- 每条指令经过 RO→EX1→EX2→EX3→EX4→MEM→WB 共 7 拍后写回
- 最终寄存器值：x4=3, x5=-1(0xFFFFFFFF), x6=0, x7=3, x8=3, x9=0xf3f2f1f0

### 8.2 测试用例2：记分牌功能测试

使用 `build.md` 中的测试用例2，验证数据依赖下的乱序执行。

关键依赖链：
- `add x4, x1, x2` → `sub x5, x1, x4`（RAW: x4）→ SUB 必须等 ADD 写回
- `add x4, x1, x2` → `and x6, x1, x4`（RAW: x4）→ AND 必须等 ADD 写回
- `or x7, x1, x2` 和 `xor x8, x1, x2` 无依赖，可与 ADD 并行执行（乱序）
- `lw x5, 0(x3)` 覆盖 x5 → `add x9, x5, x2`（RAW: x5）→ ADD(x9) 必须等 LW 写回
- `sw x9, 0(x3)` → `lw x9, 0(x3)`（RAW: 内存地址相同，但 SW 先执行完即可）

### 8.3 验证步骤

1. 将测试用例汇编为 hex：
   ```bash
   cd RVDesign/test_program/assembleProgram2hex/
   # 编辑 test.s 为测试用例内容
   bash S2hex.sh
   ```

2. 运行仿真：
   ```bash
   cd RVDesign/
   make clean && make run
   ```

3. 查看波形（`logs/wave.vcd`），重点检查：
   - 各阶段流水线寄存器的值是否正确传递
   - 功能部件状态表的写入/选择/清除时序
   - 结果寄存器状态表的标记/清除时序
   - 寄存器文件最终值是否正确
   - 指令是否实现了乱序执行（测试用例2中 OR/XOR 应先于 SUB/AND 完成）
