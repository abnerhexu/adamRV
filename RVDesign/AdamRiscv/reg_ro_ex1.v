module reg_ro_ex1(
    input  wire clk,
    input  wire rst,
    input  wire ro_valid,
    input  wire[31:0] ro_pc,
    input  wire[31:0] ro_regs_data1,
    input  wire[31:0] ro_regs_data2,
    input  wire[31:0] ro_imm,
    input  wire[2:0]  ro_func3_code,
    input  wire       ro_func7_code,
    input  wire[4:0]  ro_rd,
    input  wire[4:0]  ro_rs2,
    input  wire[2:0]  ro_alu_op,
    input  wire[1:0]  ro_alu_src1,
    input  wire[1:0]  ro_alu_src2,
    input  wire       ro_mem_read,
    input  wire       ro_mem2reg,
    input  wire       ro_mem_write,
    input  wire       ro_regs_write,
    input  wire[2:0]  ro_fu_id,

    output reg[31:0]  ex1_pc,
    output reg[31:0]  ex1_regs_data1,
    output reg[31:0]  ex1_regs_data2,
    output reg[31:0]  ex1_imm,
    output reg[2:0]   ex1_func3_code,
    output reg        ex1_func7_code,
    output reg[4:0]   ex1_rd,
    output reg[4:0]   ex1_rs2,
    output reg[2:0]   ex1_alu_op,
    output reg[1:0]   ex1_alu_src1,
    output reg[1:0]   ex1_alu_src2,
    output reg        ex1_mem_read,
    output reg        ex1_mem2reg,
    output reg        ex1_mem_write,
    output reg        ex1_regs_write,
    output reg[2:0]   ex1_fu_id
);

always @(posedge clk) begin
    if (!rst || !ro_valid) begin
        ex1_pc         <= 0;
        ex1_regs_data1 <= 0;
        ex1_regs_data2 <= 0;
        ex1_imm        <= 0;
        ex1_func3_code <= 0;
        ex1_func7_code <= 0;
        ex1_rd         <= 0;
        ex1_rs2        <= 0;
        ex1_alu_op     <= 0;
        ex1_alu_src1   <= 0;
        ex1_alu_src2   <= 0;
        ex1_mem_read   <= 0;
        ex1_mem2reg    <= 0;
        ex1_mem_write  <= 0;
        ex1_regs_write <= 0;
        ex1_fu_id      <= 0;
    end
    else begin
        ex1_pc         <= ro_pc;
        ex1_regs_data1 <= ro_regs_data1;
        ex1_regs_data2 <= ro_regs_data2;
        ex1_imm        <= ro_imm;
        ex1_func3_code <= ro_func3_code;
        ex1_func7_code <= ro_func7_code;
        ex1_rd         <= ro_rd;
        ex1_rs2        <= ro_rs2;
        ex1_alu_op     <= ro_alu_op;
        ex1_alu_src1   <= ro_alu_src1;
        ex1_alu_src2   <= ro_alu_src2;
        ex1_mem_read   <= ro_mem_read;
        ex1_mem2reg    <= ro_mem2reg;
        ex1_mem_write  <= ro_mem_write;
        ex1_regs_write <= ro_regs_write;
        ex1_fu_id      <= ro_fu_id;
    end
end

endmodule
