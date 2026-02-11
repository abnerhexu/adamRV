`include "./AdamRiscv/define.vh"

module stage_is(
    input  wire[31:0]  is_inst,
    input  wire[31:0]  is_pc,
    // FU busy flags (bit0=FU1 ... bit6=FU7)
    input  wire[6:0]   fu_busy,
    // Register status query (32 entries)
    input  wire[2:0]   reg_status_0,  reg_status_1,  reg_status_2,  reg_status_3,
    input  wire[2:0]   reg_status_4,  reg_status_5,  reg_status_6,  reg_status_7,
    input  wire[2:0]   reg_status_8,  reg_status_9,  reg_status_10, reg_status_11,
    input  wire[2:0]   reg_status_12, reg_status_13, reg_status_14, reg_status_15,
    input  wire[2:0]   reg_status_16, reg_status_17, reg_status_18, reg_status_19,
    input  wire[2:0]   reg_status_20, reg_status_21, reg_status_22, reg_status_23,
    input  wire[2:0]   reg_status_24, reg_status_25, reg_status_26, reg_status_27,
    input  wire[2:0]   reg_status_28, reg_status_29, reg_status_30, reg_status_31,
    // Outputs
    output wire[2:0]   is_fu_id,
    output wire        is_can_issue,
    output wire        is_stall,
    output wire[4:0]   is_rd,
    output wire[4:0]   is_rs1,
    output wire[4:0]   is_rs2,
    output wire[2:0]   is_func3_code,
    output wire        is_func7_code,
    output wire[2:0]   is_alu_op,
    output wire[1:0]   is_alu_src1,
    output wire[1:0]   is_alu_src2,
    output wire        is_mem_read,
    output wire        is_mem2reg,
    output wire        is_mem_write,
    output wire        is_regs_write
);

// Decode fields
wire [6:0] opcode = is_inst[6:0];
wire [2:0] func3  = is_inst[14:12];
wire       func7  = is_inst[30];

assign is_rd         = is_inst[11:7];
assign is_rs1        = is_inst[19:15];
assign is_rs2        = is_inst[24:20];
assign is_func3_code = func3;
assign is_func7_code = func7;

// Control signal generation (reuse ctrl logic)
wire br, br_addr_mode;
ctrl u_ctrl(
    .inst_op      (opcode),
    .br           (br),
    .mem_read     (is_mem_read),
    .mem2reg      (is_mem2reg),
    .alu_op       (is_alu_op),
    .mem_write    (is_mem_write),
    .alu_src1     (is_alu_src1),
    .alu_src2     (is_alu_src2),
    .br_addr_mode (br_addr_mode),
    .regs_write   (is_regs_write)
);

// FU ID mapping based on opcode + func3 + func7
reg [2:0] fu_id_r;
always @(*) begin
    case (opcode)
        `Rtype: begin
            case ({func3, func7})
                `R_ADD:  fu_id_r = `FU_ADD;
                `R_SUB:  fu_id_r = `FU_SUB;
                `R_AND:  fu_id_r = `FU_AND;
                `R_OR:   fu_id_r = `FU_OR;
                `R_XOR:  fu_id_r = `FU_XOR;
                default: fu_id_r = `FU_ADD; // SLL, SRL, SRA, SLT, SLTU -> ADD FU
            endcase
        end
        `ItypeA: fu_id_r = `FU_ADD;  // ADDI and all I-type ALU
        `ItypeL: fu_id_r = `FU_LW;   // LW, LB, LH, etc.
        `Stype:  fu_id_r = `FU_SW;   // SW, SB, SH
        `UtypeL: fu_id_r = `FU_ADD;  // LUI
        `UtypeU: fu_id_r = `FU_ADD;  // AUIPC
        `Jtype:  fu_id_r = `FU_ADD;  // JAL
        `ItypeJ: fu_id_r = `FU_ADD;  // JALR
        `Btype:  fu_id_r = `FU_ADD;  // Branch (not expected in test)
        default: fu_id_r = `FU_NONE;
    endcase
end
assign is_fu_id = fu_id_r;

// Helper: lookup register status
function [2:0] get_rs;
    input [4:0] idx;
    begin
        case (idx)
            5'd0:  get_rs = reg_status_0;  5'd1:  get_rs = reg_status_1;
            5'd2:  get_rs = reg_status_2;  5'd3:  get_rs = reg_status_3;
            5'd4:  get_rs = reg_status_4;  5'd5:  get_rs = reg_status_5;
            5'd6:  get_rs = reg_status_6;  5'd7:  get_rs = reg_status_7;
            5'd8:  get_rs = reg_status_8;  5'd9:  get_rs = reg_status_9;
            5'd10: get_rs = reg_status_10; 5'd11: get_rs = reg_status_11;
            5'd12: get_rs = reg_status_12; 5'd13: get_rs = reg_status_13;
            5'd14: get_rs = reg_status_14; 5'd15: get_rs = reg_status_15;
            5'd16: get_rs = reg_status_16; 5'd17: get_rs = reg_status_17;
            5'd18: get_rs = reg_status_18; 5'd19: get_rs = reg_status_19;
            5'd20: get_rs = reg_status_20; 5'd21: get_rs = reg_status_21;
            5'd22: get_rs = reg_status_22; 5'd23: get_rs = reg_status_23;
            5'd24: get_rs = reg_status_24; 5'd25: get_rs = reg_status_25;
            5'd26: get_rs = reg_status_26; 5'd27: get_rs = reg_status_27;
            5'd28: get_rs = reg_status_28; 5'd29: get_rs = reg_status_29;
            5'd30: get_rs = reg_status_30; 5'd31: get_rs = reg_status_31;
            default: get_rs = 3'b000;
        endcase
    end
endfunction

// Issue condition checks
wire is_valid = (is_inst != 32'b0) && (fu_id_r != `FU_NONE);
wire fu_free  = !fu_busy[fu_id_r - 3'd1];
wire no_waw   = !is_regs_write || (is_rd == 5'd0) || (get_rs(is_rd) == 3'b000);

assign is_can_issue = is_valid && fu_free && no_waw;
assign is_stall     = is_valid && !is_can_issue;

endmodule
