# 验证流程：记分牌乱序执行处理器通过两个测试用例

## 前置条件

- 已安装 Verilator（`verilator --version` 可正常输出）
- 已安装 g++（支持 C++17）
- 已安装 Python 3（用于生成测试用例 hex 文件）

## 目录结构

所有操作在 `RVDesign/` 目录下执行：

```bash
cd RVDesign/
```

---

## 测试用例 1：执行延迟测试

验证 ADD、SUB、AND、OR、XOR、LW、SW 在 4 拍 EX 流水线下的正确执行。

### 第一步：生成测试用例 1 的 hex 文件

```bash
python3 - <<'PYEOF'
import struct

def enc_r(f7, rs2, rs1, f3, rd):
    return (f7<<25)|(rs2<<20)|(rs1<<15)|(f3<<12)|(rd<<7)|0x33
def enc_i(imm, rs1, f3, rd, op=0x13):
    return ((imm&0xFFF)<<20)|(rs1<<15)|(f3<<12)|(rd<<7)|op
def enc_s(imm, rs2, rs1, f3):
    return (((imm>>5)&0x7F)<<25)|(rs2<<20)|(rs1<<15)|(f3<<12)|((imm&0x1F)<<7)|0x23
def enc_u(imm, rd, op):
    return ((imm&0xFFFFF)<<12)|(rd<<7)|op

NOP = 0x13
insts = []
insts.append(enc_i(1, 0, 0, 1))          # addi x1, x0, 1
insts.append(enc_i(2, 0, 0, 2))          # addi x2, x0, 2
insts.append(enc_u(0, 3, 0x17))          # auipc x3, 0
insts.append(enc_i(0x98, 3, 0, 3))       # addi x3, x3, 0x98
insts += [NOP]*8                          # 8 nops
insts.append(enc_r(0, 2, 1, 0, 4))       # add x4, x1, x2
insts.append(enc_r(0x20, 2, 1, 0, 5))    # sub x5, x1, x2
insts.append(enc_r(0, 2, 1, 7, 6))       # and x6, x1, x2
insts.append(enc_r(0, 2, 1, 6, 7))       # or  x7, x1, x2
insts.append(enc_r(0, 2, 1, 4, 8))       # xor x8, x1, x2
insts.append(enc_i(0, 3, 2, 9, 0x03))    # lw  x9, 0(x3)
insts.append(enc_s(0, 1, 3, 2))          # sw  x1, 0(x3)
insts.append(enc_u(0x13000, 4, 0x37))    # lui x4, 0x13000
insts.append(enc_i(4, 0, 0, 5))          # addi x5, x0, 4
insts += [NOP]*8                          # 8 nops
insts.append(enc_s(0, 5, 4, 0))          # sb  x5, 0(x4)
insts += [NOP]*10                         # 10 nops
data = [0xf3f2f1f0, 0xf7f6f5f4, 0xfbfaf9f8, 0xfffefdfc]

raw = b''.join(struct.pack('<I', x) for x in insts + data)
lines = ['@00000000']
for i in range(0, len(raw), 16):
    lines.append(' '.join(f'{b:02X}' for b in raw[i:i+16]))
with open('AdamRiscv/rom/test_program.hex', 'w') as f:
    f.write('\n'.join(lines) + '\n')
print('test_program.hex generated for test case 1')
PYEOF
```

### 第二步：编译并运行仿真

```bash
make clean && make run 2>&1 | tee test1_output.log
```

> 注：`make run` 末尾会尝试启动 `gtkwave`，如果没有图形界面可忽略该错误，不影响仿真结果。

### 第三步：检查结果

```bash
grep "WRITE REGISTER" test1_output.log | head -12
```

预期输出（第一轮写回，忽略初始化阶段的 x1/x2/x3）：

| 寄存器 | 预期值 | 含义 |
|--------|--------|------|
| x4 | 00000003 | x1 + x2 = 1 + 2 |
| x5 | ffffffff | x1 - x2 = 1 - 2（补码） |
| x6 | 00000000 | x1 & x2 = 1 & 2 |
| x7 | 00000003 | x1 \| x2 = 1 \| 2 |
| x8 | 00000003 | x1 ^ x2 = 1 ^ 2 |
| x9 | f3f2f1f0 | lw 从 data_seg 加载 |

完整预期输出：

```
WRITE REGISTER FILE: x 1 = 00000001
WRITE REGISTER FILE: x 2 = 00000002
WRITE REGISTER FILE: x 3 = 00000008
WRITE REGISTER FILE: x 3 = 000000a0
WRITE REGISTER FILE: x 4 = 00000003
WRITE REGISTER FILE: x 5 = ffffffff
WRITE REGISTER FILE: x 6 = 00000000
WRITE REGISTER FILE: x 7 = 00000003
WRITE REGISTER FILE: x 8 = 00000003
WRITE REGISTER FILE: x 9 = f3f2f1f0
WRITE REGISTER FILE: x 4 = 13000000
WRITE REGISTER FILE: x 5 = 00000004
```

---

## 测试用例 2：记分牌功能测试

验证数据依赖下的乱序执行，包括 RAW 冒险等待和无依赖指令的乱序完成。

### 第一步：生成测试用例 2 的 hex 文件

```bash
python3 - <<'PYEOF'
import struct

def enc_r(f7, rs2, rs1, f3, rd):
    return (f7<<25)|(rs2<<20)|(rs1<<15)|(f3<<12)|(rd<<7)|0x33
def enc_i(imm, rs1, f3, rd, op=0x13):
    return ((imm&0xFFF)<<20)|(rs1<<15)|(f3<<12)|(rd<<7)|op
def enc_s(imm, rs2, rs1, f3):
    return (((imm>>5)&0x7F)<<25)|(rs2<<20)|(rs1<<15)|(f3<<12)|((imm&0x1F)<<7)|0x23
def enc_u(imm, rd, op):
    return ((imm&0xFFFFF)<<12)|(rd<<7)|op

NOP = 0x13
insts = []
insts.append(enc_i(0x15, 0, 0, 1))       # addi x1, x0, 0x15
insts.append(enc_i(0x2a, 0, 0, 2))       # addi x2, x0, 0x2a
insts.append(enc_i(0, 0, 0, 4))          # addi x4, x0, 0
insts.append(enc_u(0, 3, 0x17))          # auipc x3, 0
insts.append(enc_i(0x9c, 3, 0, 3))       # addi x3, x3, 0x9c
insts += [NOP]*8                          # 8 nops
insts.append(enc_r(0, 2, 1, 0, 4))       # add x4, x1, x2
insts.append(enc_r(0x20, 4, 1, 0, 5))    # sub x5, x1, x4
insts.append(enc_r(0, 4, 1, 7, 6))       # and x6, x1, x4
insts.append(enc_r(0, 2, 1, 6, 7))       # or  x7, x1, x2
insts.append(enc_r(0, 2, 1, 4, 8))       # xor x8, x1, x2
insts.append(enc_i(0, 3, 2, 5, 0x03))    # lw  x5, 0(x3)
insts.append(enc_r(0, 2, 5, 0, 9))       # add x9, x5, x2
insts.append(enc_s(0, 9, 3, 2))          # sw  x9, 0(x3)
insts.append(enc_i(0, 3, 2, 9, 0x03))    # lw  x9, 0(x3)
insts.append(enc_u(0x13000, 4, 0x37))    # lui x4, 0x13000
insts.append(enc_i(4, 0, 0, 5))          # addi x5, x0, 4
insts += [NOP]*8                          # 8 nops
insts.append(enc_s(0, 5, 4, 0))          # sb  x5, 0(x4)
insts += [NOP]*9                          # 9 nops
data = [0xf3f2f1f0, 0xf7f6f5f4, 0xfbfaf9f8, 0xfffefdfc]

raw = b''.join(struct.pack('<I', x) for x in insts + data)
lines = ['@00000000']
for i in range(0, len(raw), 16):
    lines.append(' '.join(f'{b:02X}' for b in raw[i:i+16]))
with open('AdamRiscv/rom/test_program.hex', 'w') as f:
    f.write('\n'.join(lines) + '\n')
print('test_program.hex generated for test case 2')
PYEOF
```

### 第二步：编译并运行仿真

```bash
make clean && make run 2>&1 | tee test2_output.log
```

### 第三步：检查结果

```bash
grep "WRITE REGISTER" test2_output.log | head -15
```

预期输出（第一轮写回）：

| 寄存器 | 预期值 | 含义 |
|--------|--------|------|
| x4 | 0000003f | x1 + x2 = 0x15 + 0x2a |
| x5 | ffffffd6 | x1 - x4 = 0x15 - 0x3f（被 lw 覆盖前） |
| x6 | 00000015 | x1 & x4 = 0x15 & 0x3f |
| x7 | 0000003f | x1 \| x2 = 0x15 \| 0x2a |
| x8 | 0000003f | x1 ^ x2 = 0x15 ^ 0x2a |
| x5 | f3f2f1f0 | lw 从 data_seg 加载（覆盖 sub 结果） |
| x9 | f3f2f21a | x5 + x2 = 0xf3f2f1f0 + 0x2a |
| x9 | f3f2f21a | lw 加载 sw 写入的值（验证 store→load 正确性） |

完整预期输出：

```
WRITE REGISTER FILE: x 1 = 00000015
WRITE REGISTER FILE: x 2 = 0000002a
WRITE REGISTER FILE: x 4 = 00000000
WRITE REGISTER FILE: x 3 = 0000000c
WRITE REGISTER FILE: x 3 = 000000a8
WRITE REGISTER FILE: x 4 = 0000003f
WRITE REGISTER FILE: x 7 = 0000003f
WRITE REGISTER FILE: x 8 = 0000003f
WRITE REGISTER FILE: x 5 = ffffffd6
WRITE REGISTER FILE: x 6 = 00000015
WRITE REGISTER FILE: x 5 = f3f2f1f0
WRITE REGISTER FILE: x 9 = f3f2f21a
WRITE REGISTER FILE: x 9 = f3f2f21a
WRITE REGISTER FILE: x 4 = 13000000
WRITE REGISTER FILE: x 5 = 00000004
```

### 第四步：验证乱序执行行为

```bash
grep "\[FU\] SELECT" test2_output.log | head -10
```

关键观察点：OR（FU4）和 XOR（FU5）应先于 SUB（FU2）和 AND（FU3）被选中执行，因为 OR/XOR 的操作数 x1、x2 立即就绪，而 SUB/AND 依赖 x4（需等待 ADD 写回）。

预期选择顺序（main 段）：

```
[FU] SELECT fu=1 rd=x4 rs1=x1 rs2=x2    ← ADD 先选中
[FU] SELECT fu=4 rd=x7 rs1=x1 rs2=x2    ← OR  乱序执行（不依赖 x4）
[FU] SELECT fu=5 rd=x8 rs1=x1 rs2=x2    ← XOR 乱序执行（不依赖 x4）
[FU] SELECT fu=2 rd=x5 rs1=x1 rs2=x4    ← SUB 等 x4 就绪后执行
[FU] SELECT fu=3 rd=x6 rs1=x1 rs2=x4    ← AND 等 x4 就绪后执行
```

---

## 快速验证脚本

以下脚本自动运行两个测试用例并对比预期结果：

```bash
#!/bin/bash
cd RVDesign/
PASS=0
FAIL=0

run_test() {
    local name=$1
    local hex_script=$2
    local expected=$3

    echo "=== $name ==="
    python3 -c "$hex_script"
    make clean > /dev/null 2>&1
    make run > "${name}.log" 2>&1

    local actual
    actual=$(grep "WRITE REGISTER" "${name}.log" | head -$(echo "$expected" | wc -l))

    if [ "$actual" = "$expected" ]; then
        echo "PASS"
        PASS=$((PASS+1))
    else
        echo "FAIL"
        echo "--- expected ---"
        echo "$expected"
        echo "--- actual ---"
        echo "$actual"
        FAIL=$((FAIL+1))
    fi
    echo ""
}

# --- Test 1 hex generator ---
T1_PY='
import struct
def enc_r(f7,s2,s1,f3,rd): return (f7<<25)|(s2<<20)|(s1<<15)|(f3<<12)|(rd<<7)|0x33
def enc_i(im,s1,f3,rd,op=0x13): return ((im&0xFFF)<<20)|(s1<<15)|(f3<<12)|(rd<<7)|op
def enc_s(im,s2,s1,f3): return (((im>>5)&0x7F)<<25)|(s2<<20)|(s1<<15)|(f3<<12)|((im&0x1F)<<7)|0x23
def enc_u(im,rd,op): return ((im&0xFFFFF)<<12)|(rd<<7)|op
N=0x13; I=[]
I+=[enc_i(1,0,0,1),enc_i(2,0,0,2),enc_u(0,3,0x17),enc_i(0x98,3,0,3)]
I+=[N]*8
I+=[enc_r(0,2,1,0,4),enc_r(0x20,2,1,0,5),enc_r(0,2,1,7,6),enc_r(0,2,1,6,7)]
I+=[enc_r(0,2,1,4,8),enc_i(0,3,2,9,0x03),enc_s(0,1,3,2)]
I+=[enc_u(0x13000,4,0x37),enc_i(4,0,0,5)]+[N]*8+[enc_s(0,5,4,0)]+[N]*10
D=[0xf3f2f1f0,0xf7f6f5f4,0xfbfaf9f8,0xfffefdfc]
r=b"".join(struct.pack("<I",x) for x in I+D)
L=["@00000000"]+[" ".join(f"{b:02X}" for b in r[i:i+16]) for i in range(0,len(r),16)]
open("AdamRiscv/rom/test_program.hex","w").write("\n".join(L)+"\n")
'

T1_EXPECTED='WRITE REGISTER FILE: x 1 = 00000001
WRITE REGISTER FILE: x 2 = 00000002
WRITE REGISTER FILE: x 3 = 00000008
WRITE REGISTER FILE: x 3 = 000000a0
WRITE REGISTER FILE: x 4 = 00000003
WRITE REGISTER FILE: x 5 = ffffffff
WRITE REGISTER FILE: x 6 = 00000000
WRITE REGISTER FILE: x 7 = 00000003
WRITE REGISTER FILE: x 8 = 00000003
WRITE REGISTER FILE: x 9 = f3f2f1f0
WRITE REGISTER FILE: x 4 = 13000000
WRITE REGISTER FILE: x 5 = 00000004'

# --- Test 2 hex generator ---
T2_PY='
import struct
def enc_r(f7,s2,s1,f3,rd): return (f7<<25)|(s2<<20)|(s1<<15)|(f3<<12)|(rd<<7)|0x33
def enc_i(im,s1,f3,rd,op=0x13): return ((im&0xFFF)<<20)|(s1<<15)|(f3<<12)|(rd<<7)|op
def enc_s(im,s2,s1,f3): return (((im>>5)&0x7F)<<25)|(s2<<20)|(s1<<15)|(f3<<12)|((im&0x1F)<<7)|0x23
def enc_u(im,rd,op): return ((im&0xFFFFF)<<12)|(rd<<7)|op
N=0x13; I=[]
I+=[enc_i(0x15,0,0,1),enc_i(0x2a,0,0,2),enc_i(0,0,0,4),enc_u(0,3,0x17),enc_i(0x9c,3,0,3)]
I+=[N]*8
I+=[enc_r(0,2,1,0,4),enc_r(0x20,4,1,0,5),enc_r(0,4,1,7,6),enc_r(0,2,1,6,7)]
I+=[enc_r(0,2,1,4,8),enc_i(0,3,2,5,0x03),enc_r(0,2,5,0,9),enc_s(0,9,3,2),enc_i(0,3,2,9,0x03)]
I+=[enc_u(0x13000,4,0x37),enc_i(4,0,0,5)]+[N]*8+[enc_s(0,5,4,0)]+[N]*9
D=[0xf3f2f1f0,0xf7f6f5f4,0xfbfaf9f8,0xfffefdfc]
r=b"".join(struct.pack("<I",x) for x in I+D)
L=["@00000000"]+[" ".join(f"{b:02X}" for b in r[i:i+16]) for i in range(0,len(r),16)]
open("AdamRiscv/rom/test_program.hex","w").write("\n".join(L)+"\n")
'

T2_EXPECTED='WRITE REGISTER FILE: x 1 = 00000015
WRITE REGISTER FILE: x 2 = 0000002a
WRITE REGISTER FILE: x 4 = 00000000
WRITE REGISTER FILE: x 3 = 0000000c
WRITE REGISTER FILE: x 3 = 000000a8
WRITE REGISTER FILE: x 4 = 0000003f
WRITE REGISTER FILE: x 7 = 0000003f
WRITE REGISTER FILE: x 8 = 0000003f
WRITE REGISTER FILE: x 5 = ffffffd6
WRITE REGISTER FILE: x 6 = 00000015
WRITE REGISTER FILE: x 5 = f3f2f1f0
WRITE REGISTER FILE: x 9 = f3f2f21a
WRITE REGISTER FILE: x 9 = f3f2f21a
WRITE REGISTER FILE: x 4 = 13000000
WRITE REGISTER FILE: x 5 = 00000004'

run_test "test1" "$T1_PY" "$T1_EXPECTED"
run_test "test2" "$T2_PY" "$T2_EXPECTED"

echo "Results: $PASS passed, $FAIL failed"
```

将以上脚本保存为 `run_tests.sh`，然后执行：

```bash
bash run_tests.sh
```

两个测试均输出 `PASS` 即为通过。
