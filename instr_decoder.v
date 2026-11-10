`timescale 1ns/1ps

// RISC-V instruction decoder (RV32I subset)
// fmt encoding: 0=R, 1=I, 2=S, 3=B, 4=U, 5=J, 7=invalid

module instr_decoder (
    input  wire [31:0] instr,
    output wire [6:0]  opcode,
    output wire [2:0]  funct3,
    output wire [6:0]  funct7,
    output wire [4:0]  rs1,
    output wire [4:0]  rs2,
    output wire [4:0]  rd,
    output reg  [2:0]  fmt,
    output reg  [31:0] imm,
    output reg         reg_we,
    output reg         alu_src,
    output reg         mem_read,
    output reg         mem_write,
    output reg         mem_to_reg,
    output reg         branch,
    output reg         jump
);

    // Opcodes
    localparam [6:0] OP_R      = 7'b0110011,
                     OP_I      = 7'b0010011,
                     OP_LOAD   = 7'b0000011,
                     OP_JALR   = 7'b1100111,
                     OP_STORE  = 7'b0100011,
                     OP_BRANCH = 7'b1100011,
                     OP_LUI    = 7'b0110111,
                     OP_AUIPC  = 7'b0010111,
                     OP_JAL    = 7'b1101111;

    // Format codes
    localparam [2:0] FMT_R = 3'd0,
                     FMT_I = 3'd1,
                     FMT_S = 3'd2,
                     FMT_B = 3'd3,
                     FMT_U = 3'd4,
                     FMT_J = 3'd5,
                     FMT_X = 3'd7;

    // Field extraction (fixed bit positions in every format)
    assign opcode = instr[6:0];
    assign rd     = instr[11:7];
    assign funct3 = instr[14:12];
    assign rs1    = instr[19:15];
    assign rs2    = instr[24:20];
    assign funct7 = instr[31:25];

    // Format, immediate, and control signals
    always @(*) begin
        // Defaults: everything off
        fmt        = FMT_X;
        reg_we     = 1'b0;
        alu_src    = 1'b0;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        mem_to_reg = 1'b0;
        branch     = 1'b0;
        jump       = 1'b0;

        case (opcode)
            OP_R: begin
                fmt    = FMT_R;
                reg_we = 1'b1;
            end
            OP_I: begin
                fmt     = FMT_I;
                reg_we  = 1'b1;
                alu_src = 1'b1;
            end
            OP_LOAD: begin
                fmt        = FMT_I;
                reg_we     = 1'b1;
                alu_src    = 1'b1;
                mem_read   = 1'b1;
                mem_to_reg = 1'b1;
            end
            OP_JALR: begin
                fmt     = FMT_I;
                reg_we  = 1'b1;
                alu_src = 1'b1;
                jump    = 1'b1;
            end
            OP_STORE: begin
                fmt       = FMT_S;
                alu_src   = 1'b1;
                mem_write = 1'b1;
            end
            OP_BRANCH: begin
                fmt    = FMT_B;
                branch = 1'b1;
            end
            OP_LUI, OP_AUIPC: begin
                fmt     = FMT_U;
                reg_we  = 1'b1;
                alu_src = 1'b1;   // ALU adds the upper immediate, not rs2
            end
            OP_JAL: begin
                fmt    = FMT_J;
                reg_we = 1'b1;
                jump   = 1'b1;
            end
            default: ;
        endcase

        // Immediate generation with sign extension
        case (fmt)
            FMT_I: imm = {{20{instr[31]}}, instr[31:20]};
            FMT_S: imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            FMT_B: imm = {{19{instr[31]}}, instr[31], instr[7],
                          instr[30:25], instr[11:8], 1'b0};
            FMT_U: imm = {instr[31:12], 12'b0};
            FMT_J: imm = {{11{instr[31]}}, instr[31], instr[19:12],
                          instr[20], instr[30:21], 1'b0};
            default: imm = 32'd0;   // R-type and invalid have no immediate
        endcase
    end

endmodule
