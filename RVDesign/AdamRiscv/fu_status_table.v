`include "./AdamRiscv/define.vh"

module fu_status_table(
    input  wire        clk,
    input  wire        rst,
    // IS write
    input  wire        is_write_en,
    input  wire[2:0]   is_fu_id,
    input  wire[31:0]  is_inst,
    input  wire[31:0]  is_pc,
    input  wire[4:0]   is_rd,
    input  wire[4:0]   is_rs1,
    input  wire[4:0]   is_rs2,
    input  wire[2:0]   is_func3_code,
    input  wire        is_func7_code,
    input  wire[2:0]   is_alu_op,
    input  wire[1:0]   is_alu_src1,
    input  wire[1:0]   is_alu_src2,
    input  wire        is_mem_read,
    input  wire        is_mem2reg,
    input  wire        is_mem_write,
    input  wire        is_regs_write,
    // Register status query (for operand ready check)
    input  wire[2:0]   reg_status_0,  reg_status_1,  reg_status_2,  reg_status_3,
    input  wire[2:0]   reg_status_4,  reg_status_5,  reg_status_6,  reg_status_7,
    input  wire[2:0]   reg_status_8,  reg_status_9,  reg_status_10, reg_status_11,
    input  wire[2:0]   reg_status_12, reg_status_13, reg_status_14, reg_status_15,
    input  wire[2:0]   reg_status_16, reg_status_17, reg_status_18, reg_status_19,
    input  wire[2:0]   reg_status_20, reg_status_21, reg_status_22, reg_status_23,
    input  wire[2:0]   reg_status_24, reg_status_25, reg_status_26, reg_status_27,
    input  wire[2:0]   reg_status_28, reg_status_29, reg_status_30, reg_status_31,
    // WB clear
    input  wire        wb_clear_en,
    input  wire[2:0]   wb_fu_id,
    // RO selection output
    output wire        ro_valid,
    output wire[2:0]   ro_fu_id,
    output wire[31:0]  ro_inst,
    output wire[31:0]  ro_pc,
    output wire[4:0]   ro_rd,
    output wire[4:0]   ro_rs1,
    output wire[4:0]   ro_rs2,
    output wire[2:0]   ro_func3_code,
    output wire        ro_func7_code,
    output wire[2:0]   ro_alu_op,
    output wire[1:0]   ro_alu_src1,
    output wire[1:0]   ro_alu_src2,
    output wire        ro_mem_read,
    output wire        ro_mem2reg,
    output wire        ro_mem_write,
    output wire        ro_regs_write,
    // Status query
    output wire[6:0]   fu_busy
);

// Internal storage: 7 FU entries (index 0~6 => FU 1~7)
reg        entry_busy   [0:6];
reg [1:0]  entry_state  [0:6]; // 00=idle, 01=waiting operands, 10=in pipeline
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
reg        entry_mr     [0:6];
reg        entry_m2r    [0:6];
reg        entry_mw     [0:6];
reg        entry_rw     [0:6];

// fu_busy output
assign fu_busy = {entry_busy[6], entry_busy[5], entry_busy[4],
                  entry_busy[3], entry_busy[2], entry_busy[1], entry_busy[0]};

// Helper function: lookup register status by index
function [2:0] get_reg_status;
    input [4:0] idx;
    begin
        case (idx)
            5'd0:  get_reg_status = reg_status_0;
            5'd1:  get_reg_status = reg_status_1;
            5'd2:  get_reg_status = reg_status_2;
            5'd3:  get_reg_status = reg_status_3;
            5'd4:  get_reg_status = reg_status_4;
            5'd5:  get_reg_status = reg_status_5;
            5'd6:  get_reg_status = reg_status_6;
            5'd7:  get_reg_status = reg_status_7;
            5'd8:  get_reg_status = reg_status_8;
            5'd9:  get_reg_status = reg_status_9;
            5'd10: get_reg_status = reg_status_10;
            5'd11: get_reg_status = reg_status_11;
            5'd12: get_reg_status = reg_status_12;
            5'd13: get_reg_status = reg_status_13;
            5'd14: get_reg_status = reg_status_14;
            5'd15: get_reg_status = reg_status_15;
            5'd16: get_reg_status = reg_status_16;
            5'd17: get_reg_status = reg_status_17;
            5'd18: get_reg_status = reg_status_18;
            5'd19: get_reg_status = reg_status_19;
            5'd20: get_reg_status = reg_status_20;
            5'd21: get_reg_status = reg_status_21;
            5'd22: get_reg_status = reg_status_22;
            5'd23: get_reg_status = reg_status_23;
            5'd24: get_reg_status = reg_status_24;
            5'd25: get_reg_status = reg_status_25;
            5'd26: get_reg_status = reg_status_26;
            5'd27: get_reg_status = reg_status_27;
            5'd28: get_reg_status = reg_status_28;
            5'd29: get_reg_status = reg_status_29;
            5'd30: get_reg_status = reg_status_30;
            5'd31: get_reg_status = reg_status_31;
            default: get_reg_status = 3'b000;
        endcase
    end
endfunction

// Operand ready check (combinational)
wire can_select [0:6];
wire s1_rdy [0:6];
wire s2_rdy [0:6];

genvar g;
generate
    for (g = 0; g < 7; g = g + 1) begin : ready_check
        assign s1_rdy[g] = (entry_src1[g] == `NULL) || (entry_src1[g] == `PC) ||
                           (entry_rs1[g] == 5'd0) || (get_reg_status(entry_rs1[g]) == 3'b000);
        assign s2_rdy[g] = (entry_src2[g] == `IMM) || (entry_src2[g] == `PC_PLUS4) ||
                           (entry_rs2[g] == 5'd0) || (get_reg_status(entry_rs2[g]) == 3'b000);
        assign can_select[g] = entry_busy[g] && (entry_state[g] == 2'b01) && s1_rdy[g] && s2_rdy[g];
    end
endgenerate

// Selection logic: fixed priority FU1 > FU2 > ... > FU7
wire [2:0] sel_idx;
wire       sel_valid;

assign sel_valid = can_select[0] || can_select[1] || can_select[2] || can_select[3] ||
                   can_select[4] || can_select[5] || can_select[6];
assign sel_idx   = can_select[0] ? 3'd0 :
                   can_select[1] ? 3'd1 :
                   can_select[2] ? 3'd2 :
                   can_select[3] ? 3'd3 :
                   can_select[4] ? 3'd4 :
                   can_select[5] ? 3'd5 :
                   can_select[6] ? 3'd6 : 3'd0;

assign ro_valid      = sel_valid;
assign ro_fu_id      = sel_idx + 3'd1;
assign ro_inst       = entry_inst[sel_idx];
assign ro_pc         = entry_pc[sel_idx];
assign ro_rd         = entry_rd[sel_idx];
assign ro_rs1        = entry_rs1[sel_idx];
assign ro_rs2        = entry_rs2[sel_idx];
assign ro_func3_code = entry_func3[sel_idx];
assign ro_func7_code = entry_func7[sel_idx];
assign ro_alu_op     = entry_alu_op[sel_idx];
assign ro_alu_src1   = entry_src1[sel_idx];
assign ro_alu_src2   = entry_src2[sel_idx];
assign ro_mem_read   = entry_mr[sel_idx];
assign ro_mem2reg    = entry_m2r[sel_idx];
assign ro_mem_write  = entry_mw[sel_idx];
assign ro_regs_write = entry_rw[sel_idx];

// State transition logic
integer i;
always @(posedge clk) begin
    if (!rst) begin
        for (i = 0; i < 7; i = i + 1) begin
            entry_busy[i]   <= 0;
            entry_state[i]  <= 2'b00;
            entry_inst[i]   <= 0;
            entry_pc[i]     <= 0;
            entry_rd[i]     <= 0;
            entry_rs1[i]    <= 0;
            entry_rs2[i]    <= 0;
            entry_func3[i]  <= 0;
            entry_func7[i]  <= 0;
            entry_alu_op[i] <= 0;
            entry_src1[i]   <= 0;
            entry_src2[i]   <= 0;
            entry_mr[i]     <= 0;
            entry_m2r[i]    <= 0;
            entry_mw[i]     <= 0;
            entry_rw[i]     <= 0;
        end
    end
    else begin
        // WB clear: release FU
        if (wb_clear_en && wb_fu_id != 3'd0) begin
            entry_busy[wb_fu_id - 3'd1]  <= 0;
            entry_state[wb_fu_id - 3'd1] <= 2'b00;
        end

        // RO select: transition from waiting(01) to in-pipeline(10)
        if (sel_valid) begin
            entry_state[sel_idx] <= 2'b10;
        end

        // IS write: new instruction enters FU table
        if (is_write_en && is_fu_id != 3'd0) begin
            entry_busy[is_fu_id - 3'd1]   <= 1;
            entry_state[is_fu_id - 3'd1]  <= 2'b01;
            entry_inst[is_fu_id - 3'd1]   <= is_inst;
            entry_pc[is_fu_id - 3'd1]     <= is_pc;
            entry_rd[is_fu_id - 3'd1]     <= is_rd;
            entry_rs1[is_fu_id - 3'd1]    <= is_rs1;
            entry_rs2[is_fu_id - 3'd1]    <= is_rs2;
            entry_func3[is_fu_id - 3'd1]  <= is_func3_code;
            entry_func7[is_fu_id - 3'd1]  <= is_func7_code;
            entry_alu_op[is_fu_id - 3'd1] <= is_alu_op;
            entry_src1[is_fu_id - 3'd1]   <= is_alu_src1;
            entry_src2[is_fu_id - 3'd1]   <= is_alu_src2;
            entry_mr[is_fu_id - 3'd1]     <= is_mem_read;
            entry_m2r[is_fu_id - 3'd1]    <= is_mem2reg;
            entry_mw[is_fu_id - 3'd1]     <= is_mem_write;
            entry_rw[is_fu_id - 3'd1]     <= is_regs_write;
        end
    end
end

endmodule
