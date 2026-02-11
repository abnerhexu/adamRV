`include "./AdamRiscv/define.vh"

module stage_ex(
    input  wire[31:0]  ex4_pc,
    input  wire[31:0]  ex4_regs_data1,
    input  wire[31:0]  ex4_regs_data2,
    input  wire[31:0]  ex4_imm,
    input  wire[2:0]   ex4_func3_code,
    input  wire        ex4_func7_code,
    input  wire[2:0]   ex4_alu_op,
    input  wire[1:0]   ex4_alu_src1,
    input  wire[1:0]   ex4_alu_src2,

    output wire[31:0]  ex4_alu_o
);

wire [3:0]  alu_ctrl;
wire [31:0] op_A;
wire [31:0] op_B;
/* verilator lint_off UNUSEDSIGNAL */
wire        br_mark;
/* verilator lint_on UNUSEDSIGNAL */

alu_control u_alu_control(
    .alu_op     (ex4_alu_op     ),
    .func3_code (ex4_func3_code ),
    .func7_code (ex4_func7_code ),
    .alu_ctrl_r (alu_ctrl       )
);

alu u_alu(
    .alu_ctrl (alu_ctrl  ),
    .op_A     (op_A      ),
    .op_B     (op_B      ),
    .alu_o    (ex4_alu_o ),
    .br_mark  (br_mark   )
);

assign op_B = (ex4_alu_src2 == `PC_PLUS4) ? 32'd4 :
              (ex4_alu_src2 == `IMM) ? ex4_imm : ex4_regs_data2;
assign op_A = (ex4_alu_src1 == `NULL) ? 32'd0 :
              (ex4_alu_src1 == `PC) ? ex4_pc : ex4_regs_data1;

endmodule
