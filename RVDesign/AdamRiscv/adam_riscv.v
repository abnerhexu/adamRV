/* verilator lint_off UNUSEDSIGNAL */
module adam_riscv(
    input wire clk,
    input wire rst
);

// ============ IF Stage Signals ============
wire[31:0]    if_pc;
wire[31:0]    if_inst;

// ============ IS Stage Signals ============
wire[31:0]    is_inst;
wire[31:0]    is_pc;
wire[2:0]     is_fu_id;
wire          is_can_issue;
wire          is_stall;
wire[4:0]     is_rd, is_rs1, is_rs2;
wire[2:0]     is_func3_code;
wire          is_func7_code;
wire[2:0]     is_alu_op;
wire[1:0]     is_alu_src1, is_alu_src2;
wire          is_mem_read, is_mem2reg, is_mem_write, is_regs_write;

// ============ FU/Scoreboard Signals ============
wire[6:0]     fu_busy;
wire          fu_ro_valid;
wire[2:0]     fu_ro_fu_id;
wire[31:0]    fu_ro_inst, fu_ro_pc;
wire[4:0]     fu_ro_rd, fu_ro_rs1, fu_ro_rs2;
wire[2:0]     fu_ro_func3_code, fu_ro_alu_op;
wire          fu_ro_func7_code;
wire[1:0]     fu_ro_alu_src1, fu_ro_alu_src2;
wire          fu_ro_mem_read, fu_ro_mem2reg, fu_ro_mem_write, fu_ro_regs_write;

// ============ Register Status Table Signals ============
wire[2:0]     rs_0,  rs_1,  rs_2,  rs_3,  rs_4,  rs_5,  rs_6,  rs_7;
wire[2:0]     rs_8,  rs_9,  rs_10, rs_11, rs_12, rs_13, rs_14, rs_15;
wire[2:0]     rs_16, rs_17, rs_18, rs_19, rs_20, rs_21, rs_22, rs_23;
wire[2:0]     rs_24, rs_25, rs_26, rs_27, rs_28, rs_29, rs_30, rs_31;

// ============ RO Stage Signals ============
wire[31:0]    ro_regs_data1, ro_regs_data2, ro_imm;

// ============ WB Signals ============
wire          w_regs_en;
wire[4:0]     w_regs_addr;
wire[31:0]    w_regs_data;
wire[2:0]     wb_fu_id;

// ============ EX1 Signals ============
wire[31:0]    ex1_pc, ex1_regs_data1, ex1_regs_data2, ex1_imm;
wire[2:0]     ex1_func3_code, ex1_alu_op;
wire          ex1_func7_code;
wire[4:0]     ex1_rd, ex1_rs2;
wire[1:0]     ex1_alu_src1, ex1_alu_src2;
wire          ex1_mem_read, ex1_mem2reg, ex1_mem_write, ex1_regs_write;
wire[2:0]     ex1_fu_id;

// ============ EX2 Signals ============
wire[31:0]    ex2_pc, ex2_regs_data1, ex2_regs_data2, ex2_imm;
wire[2:0]     ex2_func3_code, ex2_alu_op;
wire          ex2_func7_code;
wire[4:0]     ex2_rd, ex2_rs2;
wire[1:0]     ex2_alu_src1, ex2_alu_src2;
wire          ex2_mem_read, ex2_mem2reg, ex2_mem_write, ex2_regs_write;
wire[2:0]     ex2_fu_id;

// ============ EX3 Signals ============
wire[31:0]    ex3_pc, ex3_regs_data1, ex3_regs_data2, ex3_imm;
wire[2:0]     ex3_func3_code, ex3_alu_op;
wire          ex3_func7_code;
wire[4:0]     ex3_rd, ex3_rs2;
wire[1:0]     ex3_alu_src1, ex3_alu_src2;
wire          ex3_mem_read, ex3_mem2reg, ex3_mem_write, ex3_regs_write;
wire[2:0]     ex3_fu_id;

// ============ EX4 Signals ============
wire[31:0]    ex4_pc, ex4_regs_data1, ex4_regs_data2, ex4_imm;
wire[2:0]     ex4_func3_code, ex4_alu_op;
wire          ex4_func7_code;
wire[4:0]     ex4_rd, ex4_rs2;
wire[1:0]     ex4_alu_src1, ex4_alu_src2;
wire          ex4_mem_read, ex4_mem2reg, ex4_mem_write, ex4_regs_write;
wire[2:0]     ex4_fu_id;
wire[31:0]    ex4_alu_o;

// ============ MEM Signals ============
wire[31:0]    me_regs_data2, me_alu_o, me_mem_data;
wire[4:0]     me_rd;
wire          me_mem_read, me_mem2reg, me_mem_write, me_regs_write;
wire[2:0]     me_func3_code, me_fu_id;

// ============ WB Pipeline Signals ============
wire[31:0]    wb_mem_data, wb_alu_o;
wire          wb_mem2reg;

// IS write enable for scoreboard
wire is_write_en = is_can_issue;
wire rs_write_en = is_can_issue && is_regs_write && (is_rd != 5'd0);
// WB clear: FU table needs clearing for ALL instructions (including SW)
wire wb_fu_clear_en = (wb_fu_id != 3'd0);
// WB clear: register status table only clears for register-writing instructions
wire wb_rs_clear_en = w_regs_en;

// ==================== IF Stage ====================
stage_if u_stage_if(
    .clk      (clk       ),
    .rst      (rst       ),
    .pc_stall (is_stall  ),
    .br_addr  (32'b0     ),
    .br_ctrl  (1'b0      ),
    .if_inst  (if_inst   ),
    .if_pc    (if_pc     )
);

// ==================== IF/IS Pipeline Register ====================
reg_if_is u_reg_if_is(
    .clk         (clk       ),
    .rst         (rst       ),
    .if_pc       (if_pc     ),
    .if_inst     (if_inst   ),
    .is_inst     (is_inst   ),
    .is_pc       (is_pc     ),
    .if_is_flush (1'b0      ),
    .if_is_stall (is_stall  )
);

// ==================== IS (Issue) Stage ====================
stage_is u_stage_is(
    .is_inst       (is_inst   ),
    .is_pc         (is_pc     ),
    .fu_busy       (fu_busy   ),
    .reg_status_0  (rs_0 ), .reg_status_1  (rs_1 ), .reg_status_2  (rs_2 ), .reg_status_3  (rs_3 ),
    .reg_status_4  (rs_4 ), .reg_status_5  (rs_5 ), .reg_status_6  (rs_6 ), .reg_status_7  (rs_7 ),
    .reg_status_8  (rs_8 ), .reg_status_9  (rs_9 ), .reg_status_10 (rs_10), .reg_status_11 (rs_11),
    .reg_status_12 (rs_12), .reg_status_13 (rs_13), .reg_status_14 (rs_14), .reg_status_15 (rs_15),
    .reg_status_16 (rs_16), .reg_status_17 (rs_17), .reg_status_18 (rs_18), .reg_status_19 (rs_19),
    .reg_status_20 (rs_20), .reg_status_21 (rs_21), .reg_status_22 (rs_22), .reg_status_23 (rs_23),
    .reg_status_24 (rs_24), .reg_status_25 (rs_25), .reg_status_26 (rs_26), .reg_status_27 (rs_27),
    .reg_status_28 (rs_28), .reg_status_29 (rs_29), .reg_status_30 (rs_30), .reg_status_31 (rs_31),
    .is_fu_id      (is_fu_id      ),
    .is_can_issue  (is_can_issue  ),
    .is_stall      (is_stall      ),
    .is_rd         (is_rd         ),
    .is_rs1        (is_rs1        ),
    .is_rs2        (is_rs2        ),
    .is_func3_code (is_func3_code ),
    .is_func7_code (is_func7_code ),
    .is_alu_op     (is_alu_op     ),
    .is_alu_src1   (is_alu_src1   ),
    .is_alu_src2   (is_alu_src2   ),
    .is_mem_read   (is_mem_read   ),
    .is_mem2reg    (is_mem2reg    ),
    .is_mem_write  (is_mem_write  ),
    .is_regs_write (is_regs_write )
);

// ==================== Register Status Table ====================
reg_status_table u_reg_status_table(
    .clk         (clk         ),
    .rst         (rst         ),
    .is_write_en (rs_write_en ),
    .is_rd       (is_rd       ),
    .is_fu_id    (is_fu_id    ),
    .wb_clear_en (wb_rs_clear_en ),
    .wb_rd       (w_regs_addr    ),
    .wb_fu_id    (wb_fu_id       ),
    .status_0  (rs_0 ), .status_1  (rs_1 ), .status_2  (rs_2 ), .status_3  (rs_3 ),
    .status_4  (rs_4 ), .status_5  (rs_5 ), .status_6  (rs_6 ), .status_7  (rs_7 ),
    .status_8  (rs_8 ), .status_9  (rs_9 ), .status_10 (rs_10), .status_11 (rs_11),
    .status_12 (rs_12), .status_13 (rs_13), .status_14 (rs_14), .status_15 (rs_15),
    .status_16 (rs_16), .status_17 (rs_17), .status_18 (rs_18), .status_19 (rs_19),
    .status_20 (rs_20), .status_21 (rs_21), .status_22 (rs_22), .status_23 (rs_23),
    .status_24 (rs_24), .status_25 (rs_25), .status_26 (rs_26), .status_27 (rs_27),
    .status_28 (rs_28), .status_29 (rs_29), .status_30 (rs_30), .status_31 (rs_31)
);

// ==================== Functional Unit Status Table ====================
fu_status_table u_fu_status_table(
    .clk           (clk           ),
    .rst           (rst           ),
    .is_write_en   (is_write_en   ),
    .is_fu_id      (is_fu_id      ),
    .is_inst       (is_inst       ),
    .is_pc         (is_pc         ),
    .is_rd         (is_rd         ),
    .is_rs1        (is_rs1        ),
    .is_rs2        (is_rs2        ),
    .is_func3_code (is_func3_code ),
    .is_func7_code (is_func7_code ),
    .is_alu_op     (is_alu_op     ),
    .is_alu_src1   (is_alu_src1   ),
    .is_alu_src2   (is_alu_src2   ),
    .is_mem_read   (is_mem_read   ),
    .is_mem2reg    (is_mem2reg    ),
    .is_mem_write  (is_mem_write  ),
    .is_regs_write (is_regs_write ),
    .reg_status_0  (rs_0 ), .reg_status_1  (rs_1 ), .reg_status_2  (rs_2 ), .reg_status_3  (rs_3 ),
    .reg_status_4  (rs_4 ), .reg_status_5  (rs_5 ), .reg_status_6  (rs_6 ), .reg_status_7  (rs_7 ),
    .reg_status_8  (rs_8 ), .reg_status_9  (rs_9 ), .reg_status_10 (rs_10), .reg_status_11 (rs_11),
    .reg_status_12 (rs_12), .reg_status_13 (rs_13), .reg_status_14 (rs_14), .reg_status_15 (rs_15),
    .reg_status_16 (rs_16), .reg_status_17 (rs_17), .reg_status_18 (rs_18), .reg_status_19 (rs_19),
    .reg_status_20 (rs_20), .reg_status_21 (rs_21), .reg_status_22 (rs_22), .reg_status_23 (rs_23),
    .reg_status_24 (rs_24), .reg_status_25 (rs_25), .reg_status_26 (rs_26), .reg_status_27 (rs_27),
    .reg_status_28 (rs_28), .reg_status_29 (rs_29), .reg_status_30 (rs_30), .reg_status_31 (rs_31),
    .wb_clear_en   (wb_fu_clear_en),
    .wb_fu_id      (wb_fu_id      ),
    .ro_valid      (fu_ro_valid      ),
    .ro_fu_id      (fu_ro_fu_id      ),
    .ro_inst       (fu_ro_inst       ),
    .ro_pc         (fu_ro_pc         ),
    .ro_rd         (fu_ro_rd         ),
    .ro_rs1        (fu_ro_rs1        ),
    .ro_rs2        (fu_ro_rs2        ),
    .ro_func3_code (fu_ro_func3_code ),
    .ro_func7_code (fu_ro_func7_code ),
    .ro_alu_op     (fu_ro_alu_op     ),
    .ro_alu_src1   (fu_ro_alu_src1   ),
    .ro_alu_src2   (fu_ro_alu_src2   ),
    .ro_mem_read   (fu_ro_mem_read   ),
    .ro_mem2reg    (fu_ro_mem2reg    ),
    .ro_mem_write  (fu_ro_mem_write  ),
    .ro_regs_write (fu_ro_regs_write ),
    .fu_busy       (fu_busy          )
);

// ==================== RO (Read Operands) Stage ====================
stage_ro u_stage_ro(
    .clk           (clk              ),
    .rst           (rst              ),
    .ro_inst       (fu_ro_inst       ),
    .ro_rs1        (fu_ro_rs1        ),
    .ro_rs2        (fu_ro_rs2        ),
    .w_regs_en     (w_regs_en        ),
    .w_regs_addr   (w_regs_addr      ),
    .w_regs_data   (w_regs_data      ),
    .ro_regs_data1 (ro_regs_data1    ),
    .ro_regs_data2 (ro_regs_data2    ),
    .ro_imm        (ro_imm           )
);

// ==================== RO/EX1 Pipeline Register ====================
reg_ro_ex1 u_reg_ro_ex1(
    .clk            (clk              ),
    .rst            (rst              ),
    .ro_valid       (fu_ro_valid      ),
    .ro_pc          (fu_ro_pc         ),
    .ro_regs_data1  (ro_regs_data1    ),
    .ro_regs_data2  (ro_regs_data2    ),
    .ro_imm         (ro_imm           ),
    .ro_func3_code  (fu_ro_func3_code ),
    .ro_func7_code  (fu_ro_func7_code ),
    .ro_rd          (fu_ro_rd         ),
    .ro_rs2         (fu_ro_rs2        ),
    .ro_alu_op      (fu_ro_alu_op     ),
    .ro_alu_src1    (fu_ro_alu_src1   ),
    .ro_alu_src2    (fu_ro_alu_src2   ),
    .ro_mem_read    (fu_ro_mem_read   ),
    .ro_mem2reg     (fu_ro_mem2reg    ),
    .ro_mem_write   (fu_ro_mem_write  ),
    .ro_regs_write  (fu_ro_regs_write ),
    .ro_fu_id       (fu_ro_fu_id      ),
    .ex1_pc         (ex1_pc           ),
    .ex1_regs_data1 (ex1_regs_data1   ),
    .ex1_regs_data2 (ex1_regs_data2   ),
    .ex1_imm        (ex1_imm          ),
    .ex1_func3_code (ex1_func3_code   ),
    .ex1_func7_code (ex1_func7_code   ),
    .ex1_rd         (ex1_rd           ),
    .ex1_rs2        (ex1_rs2          ),
    .ex1_alu_op     (ex1_alu_op       ),
    .ex1_alu_src1   (ex1_alu_src1     ),
    .ex1_alu_src2   (ex1_alu_src2     ),
    .ex1_mem_read   (ex1_mem_read     ),
    .ex1_mem2reg    (ex1_mem2reg      ),
    .ex1_mem_write  (ex1_mem_write    ),
    .ex1_regs_write (ex1_regs_write   ),
    .ex1_fu_id      (ex1_fu_id        )
);

// ==================== EX1/EX2 Pipeline Register ====================
reg_ex1_ex2 u_reg_ex1_ex2(
    .clk            (clk            ),
    .rst            (rst            ),
    .ex1_pc         (ex1_pc         ),
    .ex1_regs_data1 (ex1_regs_data1 ),
    .ex1_regs_data2 (ex1_regs_data2 ),
    .ex1_imm        (ex1_imm        ),
    .ex1_func3_code (ex1_func3_code ),
    .ex1_func7_code (ex1_func7_code ),
    .ex1_rd         (ex1_rd         ),
    .ex1_rs2        (ex1_rs2        ),
    .ex1_alu_op     (ex1_alu_op     ),
    .ex1_alu_src1   (ex1_alu_src1   ),
    .ex1_alu_src2   (ex1_alu_src2   ),
    .ex1_mem_read   (ex1_mem_read   ),
    .ex1_mem2reg    (ex1_mem2reg    ),
    .ex1_mem_write  (ex1_mem_write  ),
    .ex1_regs_write (ex1_regs_write ),
    .ex1_fu_id      (ex1_fu_id      ),
    .ex2_pc         (ex2_pc         ),
    .ex2_regs_data1 (ex2_regs_data1 ),
    .ex2_regs_data2 (ex2_regs_data2 ),
    .ex2_imm        (ex2_imm        ),
    .ex2_func3_code (ex2_func3_code ),
    .ex2_func7_code (ex2_func7_code ),
    .ex2_rd         (ex2_rd         ),
    .ex2_rs2        (ex2_rs2        ),
    .ex2_alu_op     (ex2_alu_op     ),
    .ex2_alu_src1   (ex2_alu_src1   ),
    .ex2_alu_src2   (ex2_alu_src2   ),
    .ex2_mem_read   (ex2_mem_read   ),
    .ex2_mem2reg    (ex2_mem2reg    ),
    .ex2_mem_write  (ex2_mem_write  ),
    .ex2_regs_write (ex2_regs_write ),
    .ex2_fu_id      (ex2_fu_id      )
);

// ==================== EX2/EX3 Pipeline Register ====================
reg_ex2_ex3 u_reg_ex2_ex3(
    .clk            (clk            ),
    .rst            (rst            ),
    .ex2_pc         (ex2_pc         ),
    .ex2_regs_data1 (ex2_regs_data1 ),
    .ex2_regs_data2 (ex2_regs_data2 ),
    .ex2_imm        (ex2_imm        ),
    .ex2_func3_code (ex2_func3_code ),
    .ex2_func7_code (ex2_func7_code ),
    .ex2_rd         (ex2_rd         ),
    .ex2_rs2        (ex2_rs2        ),
    .ex2_alu_op     (ex2_alu_op     ),
    .ex2_alu_src1   (ex2_alu_src1   ),
    .ex2_alu_src2   (ex2_alu_src2   ),
    .ex2_mem_read   (ex2_mem_read   ),
    .ex2_mem2reg    (ex2_mem2reg    ),
    .ex2_mem_write  (ex2_mem_write  ),
    .ex2_regs_write (ex2_regs_write ),
    .ex2_fu_id      (ex2_fu_id      ),
    .ex3_pc         (ex3_pc         ),
    .ex3_regs_data1 (ex3_regs_data1 ),
    .ex3_regs_data2 (ex3_regs_data2 ),
    .ex3_imm        (ex3_imm        ),
    .ex3_func3_code (ex3_func3_code ),
    .ex3_func7_code (ex3_func7_code ),
    .ex3_rd         (ex3_rd         ),
    .ex3_rs2        (ex3_rs2        ),
    .ex3_alu_op     (ex3_alu_op     ),
    .ex3_alu_src1   (ex3_alu_src1   ),
    .ex3_alu_src2   (ex3_alu_src2   ),
    .ex3_mem_read   (ex3_mem_read   ),
    .ex3_mem2reg    (ex3_mem2reg    ),
    .ex3_mem_write  (ex3_mem_write  ),
    .ex3_regs_write (ex3_regs_write ),
    .ex3_fu_id      (ex3_fu_id      )
);

// ==================== EX3/EX4 Pipeline Register ====================
reg_ex3_ex4 u_reg_ex3_ex4(
    .clk            (clk            ),
    .rst            (rst            ),
    .ex3_pc         (ex3_pc         ),
    .ex3_regs_data1 (ex3_regs_data1 ),
    .ex3_regs_data2 (ex3_regs_data2 ),
    .ex3_imm        (ex3_imm        ),
    .ex3_func3_code (ex3_func3_code ),
    .ex3_func7_code (ex3_func7_code ),
    .ex3_rd         (ex3_rd         ),
    .ex3_rs2        (ex3_rs2        ),
    .ex3_alu_op     (ex3_alu_op     ),
    .ex3_alu_src1   (ex3_alu_src1   ),
    .ex3_alu_src2   (ex3_alu_src2   ),
    .ex3_mem_read   (ex3_mem_read   ),
    .ex3_mem2reg    (ex3_mem2reg    ),
    .ex3_mem_write  (ex3_mem_write  ),
    .ex3_regs_write (ex3_regs_write ),
    .ex3_fu_id      (ex3_fu_id      ),
    .ex4_pc         (ex4_pc         ),
    .ex4_regs_data1 (ex4_regs_data1 ),
    .ex4_regs_data2 (ex4_regs_data2 ),
    .ex4_imm        (ex4_imm        ),
    .ex4_func3_code (ex4_func3_code ),
    .ex4_func7_code (ex4_func7_code ),
    .ex4_rd         (ex4_rd         ),
    .ex4_rs2        (ex4_rs2        ),
    .ex4_alu_op     (ex4_alu_op     ),
    .ex4_alu_src1   (ex4_alu_src1   ),
    .ex4_alu_src2   (ex4_alu_src2   ),
    .ex4_mem_read   (ex4_mem_read   ),
    .ex4_mem2reg    (ex4_mem2reg    ),
    .ex4_mem_write  (ex4_mem_write  ),
    .ex4_regs_write (ex4_regs_write ),
    .ex4_fu_id      (ex4_fu_id      )
);

// ==================== EX4 (ALU Execution) Stage ====================
stage_ex u_stage_ex(
    .ex4_pc         (ex4_pc         ),
    .ex4_regs_data1 (ex4_regs_data1 ),
    .ex4_regs_data2 (ex4_regs_data2 ),
    .ex4_imm        (ex4_imm        ),
    .ex4_func3_code (ex4_func3_code ),
    .ex4_func7_code (ex4_func7_code ),
    .ex4_alu_op     (ex4_alu_op     ),
    .ex4_alu_src1   (ex4_alu_src1   ),
    .ex4_alu_src2   (ex4_alu_src2   ),
    .ex4_alu_o      (ex4_alu_o      )
);

// ==================== EX4/MEM Pipeline Register ====================
reg_ex_mem u_reg_ex_mem(
    .clk            (clk            ),
    .rst            (rst            ),
    .ex4_regs_data2 (ex4_regs_data2 ),
    .ex4_alu_o      (ex4_alu_o      ),
    .ex4_rd         (ex4_rd         ),
    .ex4_mem_read   (ex4_mem_read   ),
    .ex4_mem2reg    (ex4_mem2reg    ),
    .ex4_mem_write  (ex4_mem_write  ),
    .ex4_regs_write (ex4_regs_write ),
    .ex4_func3_code (ex4_func3_code ),
    .ex4_fu_id      (ex4_fu_id      ),
    .me_regs_data2  (me_regs_data2  ),
    .me_alu_o       (me_alu_o       ),
    .me_rd          (me_rd          ),
    .me_mem_read    (me_mem_read    ),
    .me_mem2reg     (me_mem2reg     ),
    .me_mem_write   (me_mem_write   ),
    .me_regs_write  (me_regs_write  ),
    .me_func3_code  (me_func3_code  ),
    .me_fu_id       (me_fu_id       )
);

// ==================== MEM Stage ====================
stage_mem u_stage_mem(
    .clk           (clk           ),
    .rst           (rst           ),
    .me_regs_data2 (me_regs_data2 ),
    .me_alu_o      (me_alu_o      ),
    .me_mem_read   (me_mem_read   ),
    .me_mem_write  (me_mem_write  ),
    .me_func3_code (me_func3_code ),
    .me_mem_data   (me_mem_data   )
);

// ==================== MEM/WB Pipeline Register ====================
reg_mem_wb u_reg_mem_wb(
    .clk           (clk           ),
    .rst           (rst           ),
    .me_mem_data   (me_mem_data   ),
    .me_alu_o      (me_alu_o      ),
    .me_rd         (me_rd         ),
    .me_mem2reg    (me_mem2reg    ),
    .me_regs_write (me_regs_write ),
    .me_fu_id      (me_fu_id      ),
    .wb_mem_data   (wb_mem_data   ),
    .wb_alu_o      (wb_alu_o      ),
    .wb_rd         (w_regs_addr   ),
    .wb_mem2reg    (wb_mem2reg    ),
    .wb_regs_write (w_regs_en     ),
    .wb_fu_id      (wb_fu_id      )
);

// ==================== WB Stage ====================
stage_wb u_stage_wb(
    .wb_mem_data (wb_mem_data ),
    .wb_alu_o    (wb_alu_o    ),
    .wb_mem2reg  (wb_mem2reg  ),
    .w_regs_data (w_regs_data )
);

// Debug output
always @(posedge clk) begin
    if (rst) begin
        if (is_can_issue)
            $display("[IS] ISSUE inst=%h pc=%h fu=%0d rd=x%0d", is_inst, is_pc, is_fu_id, is_rd);
        if (is_stall)
            $display("[IS] STALL inst=%h pc=%h fu=%0d busy=%b", is_inst, is_pc, is_fu_id, fu_busy);
        if (fu_ro_valid)
            $display("[FU] SELECT fu=%0d rd=x%0d rs1=x%0d rs2=x%0d", fu_ro_fu_id, fu_ro_rd, fu_ro_rs1, fu_ro_rs2);
        if (wb_fu_clear_en)
            $display("[WB] CLEAR fu=%0d rd=x%0d wen=%0d data=%h", wb_fu_id, w_regs_addr, w_regs_en, w_regs_data);
    end
end

endmodule
