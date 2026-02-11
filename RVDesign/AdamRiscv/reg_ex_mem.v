module reg_ex_mem(
    input  wire clk,
    input  wire rst,
    input  wire[31:0] ex4_regs_data2,
    input  wire[31:0] ex4_alu_o,
    input  wire[4:0]  ex4_rd,
    input  wire       ex4_mem_read,
    input  wire       ex4_mem2reg,
    input  wire       ex4_mem_write,
    input  wire       ex4_regs_write,
    input  wire[2:0]  ex4_func3_code,
    input  wire[2:0]  ex4_fu_id,

    output reg[31:0]  me_regs_data2,
    output reg[31:0]  me_alu_o,
    output reg[4:0]   me_rd,
    output reg        me_mem_read,
    output reg        me_mem2reg,
    output reg        me_mem_write,
    output reg        me_regs_write,
    output reg[2:0]   me_func3_code,
    output reg[2:0]   me_fu_id
);

always @(posedge clk) begin
    if (!rst) begin
        me_regs_data2  <= 0;
        me_alu_o       <= 0;
        me_rd          <= 0;
        me_mem_read    <= 0;
        me_mem2reg     <= 0;
        me_mem_write   <= 0;
        me_regs_write  <= 0;
        me_func3_code  <= 0;
        me_fu_id       <= 0;
    end
    else begin
        me_regs_data2  <= ex4_regs_data2;
        me_alu_o       <= ex4_alu_o;
        me_rd          <= ex4_rd;
        me_mem_read    <= ex4_mem_read;
        me_mem2reg     <= ex4_mem2reg;
        me_mem_write   <= ex4_mem_write;
        me_regs_write  <= ex4_regs_write;
        me_func3_code  <= ex4_func3_code;
        me_fu_id       <= ex4_fu_id;
    end
end

endmodule
