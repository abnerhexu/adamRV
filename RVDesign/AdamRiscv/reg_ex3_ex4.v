module reg_ex3_ex4(
    input  wire clk,
    input  wire rst,
    input  wire[31:0] ex3_pc,
    input  wire[31:0] ex3_regs_data1,
    input  wire[31:0] ex3_regs_data2,
    input  wire[31:0] ex3_imm,
    input  wire[2:0]  ex3_func3_code,
    input  wire       ex3_func7_code,
    input  wire[4:0]  ex3_rd,
    input  wire[4:0]  ex3_rs2,
    input  wire[2:0]  ex3_alu_op,
    input  wire[1:0]  ex3_alu_src1,
    input  wire[1:0]  ex3_alu_src2,
    input  wire       ex3_mem_read,
    input  wire       ex3_mem2reg,
    input  wire       ex3_mem_write,
    input  wire       ex3_regs_write,
    input  wire[2:0]  ex3_fu_id,

    output reg[31:0]  ex4_pc,
    output reg[31:0]  ex4_regs_data1,
    output reg[31:0]  ex4_regs_data2,
    output reg[31:0]  ex4_imm,
    output reg[2:0]   ex4_func3_code,
    output reg        ex4_func7_code,
    output reg[4:0]   ex4_rd,
    output reg[4:0]   ex4_rs2,
    output reg[2:0]   ex4_alu_op,
    output reg[1:0]   ex4_alu_src1,
    output reg[1:0]   ex4_alu_src2,
    output reg        ex4_mem_read,
    output reg        ex4_mem2reg,
    output reg        ex4_mem_write,
    output reg        ex4_regs_write,
    output reg[2:0]   ex4_fu_id
);

always @(posedge clk) begin
    if (!rst) begin
        ex4_pc         <= 0;
        ex4_regs_data1 <= 0;
        ex4_regs_data2 <= 0;
        ex4_imm        <= 0;
        ex4_func3_code <= 0;
        ex4_func7_code <= 0;
        ex4_rd         <= 0;
        ex4_rs2        <= 0;
        ex4_alu_op     <= 0;
        ex4_alu_src1   <= 0;
        ex4_alu_src2   <= 0;
        ex4_mem_read   <= 0;
        ex4_mem2reg    <= 0;
        ex4_mem_write  <= 0;
        ex4_regs_write <= 0;
        ex4_fu_id      <= 0;
    end
    else begin
        ex4_pc         <= ex3_pc;
        ex4_regs_data1 <= ex3_regs_data1;
        ex4_regs_data2 <= ex3_regs_data2;
        ex4_imm        <= ex3_imm;
        ex4_func3_code <= ex3_func3_code;
        ex4_func7_code <= ex3_func7_code;
        ex4_rd         <= ex3_rd;
        ex4_rs2        <= ex3_rs2;
        ex4_alu_op     <= ex3_alu_op;
        ex4_alu_src1   <= ex3_alu_src1;
        ex4_alu_src2   <= ex3_alu_src2;
        ex4_mem_read   <= ex3_mem_read;
        ex4_mem2reg    <= ex3_mem2reg;
        ex4_mem_write  <= ex3_mem_write;
        ex4_regs_write <= ex3_regs_write;
        ex4_fu_id      <= ex3_fu_id;
    end
end

endmodule
