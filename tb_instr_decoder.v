`timescale 1ns/1ps

// Self-checking testbench for instr_decoder.
// Every decoder output is compared against a hand-computed expected value.
// Expected values come from the RISC-V base ISA encoding, not from the decoder.

module tb_instr_decoder;

    // Stimulus and decoder outputs
    reg  [31:0] instr;
    wire [6:0]  opcode;
    wire [2:0]  funct3;
    wire [6:0]  funct7;
    wire [4:0]  rs1, rs2, rd;
    wire [2:0]  fmt;
    wire [31:0] imm;
    wire        reg_we, alu_src, mem_read, mem_write, mem_to_reg, branch, jump;

    // Device under test
    instr_decoder dut (
        .instr(instr), .opcode(opcode), .funct3(funct3), .funct7(funct7),
        .rs1(rs1), .rs2(rs2), .rd(rd), .fmt(fmt), .imm(imm),
        .reg_we(reg_we), .alu_src(alu_src), .mem_read(mem_read),
        .mem_write(mem_write), .mem_to_reg(mem_to_reg),
        .branch(branch), .jump(jump)
    );

    integer errors;
    integer i;
    reg [31:0] r;

    // Apply one instruction, wait for settling, compare all outputs.
    // Argument order matches the table in each check() call below.
    task check;
        input [31:0]     word;
        input [2:0]      e_fmt;
        input [31:0]     e_imm;
        input [4:0]      e_rd, e_rs1, e_rs2;
        input [2:0]      e_f3;
        input [6:0]      e_f7;
        input            e_we, e_as, e_mr, e_mw, e_m2r, e_br, e_jmp;
        input [8*32-1:0] name;
        begin
            instr = word;
            #1;   // combinational logic settles within 1 ns
            if (fmt !== e_fmt || imm !== e_imm ||
                rd !== e_rd || rs1 !== e_rs1 || rs2 !== e_rs2 ||
                funct3 !== e_f3 || funct7 !== e_f7 ||
                reg_we !== e_we || alu_src !== e_as ||
                mem_read !== e_mr || mem_write !== e_mw ||
                mem_to_reg !== e_m2r || branch !== e_br || jump !== e_jmp) begin
                errors = errors + 1;
                $display("FAIL %0s: instr=%h fmt=%0d imm=%h rd=%0d rs1=%0d rs2=%0d f3=%0d f7=%0d we=%b as=%b mr=%b mw=%b m2r=%b br=%b jmp=%b",
                         name, word, fmt, imm, rd, rs1, rs2, funct3, funct7,
                         reg_we, alu_src, mem_read, mem_write, mem_to_reg, branch, jump);
            end else begin
                $display("PASS %0s", name);
            end
        end
    endtask

    initial begin
        $dumpfile("instr_decoder.vcd");
        $dumpvars(0, tb_instr_decoder);
        errors = 0;

        // Columns: word, fmt, imm, rd, rs1, rs2, funct3, funct7,
        //          reg_we, alu_src, mem_read, mem_write, mem_to_reg, branch, jump, name

        // I-type: addi x1,x0,-5 (sign-extended immediate)
        check(32'hFFB00093, 3'd1, 32'hFFFFFFFB, 5'd1, 5'd0, 5'd27, 3'd0, 7'h7F,
              1, 1, 0, 0, 0, 0, 0, "addi x1,x0,-5");

        // R-type
        check(32'h002081B3, 3'd0, 32'd0, 5'd3, 5'd1, 5'd2, 3'd0, 7'd0,
              1, 0, 0, 0, 0, 0, 0, "add x3,x1,x2");
        check(32'h402081B3, 3'd0, 32'd0, 5'd3, 5'd1, 5'd2, 3'd0, 7'h20,
              1, 0, 0, 0, 0, 0, 0, "sub x3,x1,x2");

        // S-type: stores write memory, never a register
        check(32'h0020A423, 3'd2, 32'd8, 5'd8, 5'd1, 5'd2, 3'd2, 7'd0,
              0, 1, 0, 1, 0, 0, 0, "sw x2,8(x1)");
        check(32'hFE20AE23, 3'd2, 32'hFFFFFFFC, 5'd28, 5'd1, 5'd2, 3'd2, 7'h7F,
              0, 1, 0, 1, 0, 0, 0, "sw x2,-4(x1)");

        // B-type: branch flag set, no register write
        check(32'hFE000EE3, 3'd3, 32'hFFFFFFFC, 5'd29, 5'd0, 5'd0, 3'd0, 7'h7F,
              0, 0, 0, 0, 0, 1, 0, "beq x0,x0,-4");

        // U-type: ALU uses the upper immediate (alu_src = 1)
        check(32'h123452B7, 3'd4, 32'h12345000, 5'd5, 5'd8, 5'd3, 3'd5, 7'd9,
              1, 1, 0, 0, 0, 0, 0, "lui x5,0x12345");

        // J-type: jump flag set; x0 write is still flagged (register file ignores x0)
        check(32'h008000EF, 3'd5, 32'd8, 5'd1, 5'd0, 5'd8, 3'd0, 7'd0,
              1, 0, 0, 0, 0, 0, 1, "jal x1,+8");
        check(32'hFFDFF06F, 3'd5, 32'hFFFFFFFC, 5'd0, 5'd31, 5'd29, 3'd7, 7'h7F,
              1, 0, 0, 0, 0, 0, 1, "jal x0,-4");

        // Invalid opcode: every control off, format invalid
        check(32'h00000000, 3'd7, 32'd0, 5'd0, 5'd0, 5'd0, 3'd0, 7'd0,
              0, 0, 0, 0, 0, 0, 0, "invalid opcode");

        // Random words: field extraction must match raw bit positions
        for (i = 0; i < 500; i = i + 1) begin
            r = $random;
            instr = r;
            #1;
            if (opcode !== r[6:0] || funct3 !== r[14:12] || funct7 !== r[31:25] ||
                rs1 !== r[19:15] || rs2 !== r[24:20] || rd !== r[11:7]) begin
                errors = errors + 1;
                $display("FAIL random field extraction: instr=%h", r);
            end
        end

        if (errors == 0) $display("PASS: all decoder tests passed");
        else             $display("FAIL: %0d error(s)", errors);

        $finish;
    end

endmodule
