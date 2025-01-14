////////////////////////////////////////////////////////////////////////////////
// THIS FILE WAS AUTOMATICALLY GENERATED FROM generate_matmul.v.mako
// DO NOT EDIT
////////////////////////////////////////////////////////////////////////////////

`timescale 1ns/1ns
`define DWIDTH 8
`define AWIDTH 11
`define MEM_SIZE 2048

`define MAT_MUL_SIZE 16
`define MASK_WIDTH 16
`define LOG2_MAT_MUL_SIZE 4

`define BB_MAT_MUL_SIZE `MAT_MUL_SIZE
`define NUM_CYCLES_IN_MAC 3
`define MEM_ACCESS_LATENCY 1
`define REG_DATAWIDTH 32
`define REG_ADDRWIDTH 8
`define ADDR_STRIDE_WIDTH 8
`define MAX_BITS_POOL 3
`define VCS

module matmul_16x16_systolic(
    clk,
    reset,
    pe_reset,
    start_mat_mul,
    done_mat_mul,
    num_matrices_A,
    num_matrices_B,
    address_mat_a,
    address_mat_b,
    address_stride_a,
    address_stride_b,
    a_data,
    b_data,
    a_data_in,  // Data values coming in from previous matmul - systolic connections
    b_data_in,  // Data values coming in from previous matmul - weight matrix 
    c_data_in,  // Data values coming in from previous matmul - systolic shifting
    c_data_out, // Data values going out to next matmul - systolic shifting
    a_data_out,
    b_data_out,
    a_addr,
    b_addr,
    c_addr,
    c_data_available,
    matrixC15_0,
    matrixC15_1,
    matrixC15_2,
    matrixC15_3,
    matrixC15_4,
    matrixC15_5,
    matrixC15_6,
    matrixC15_7,
    matrixC15_8,
    matrixC15_9,
    matrixC15_10,
    matrixC15_11,
    matrixC15_12,
    matrixC15_13,
    matrixC15_14,
    matrixC15_15,
    validity_mask_a_rows,
    validity_mask_a_cols_b_rows,
    validity_mask_b_cols,
    a_loc,
    b_loc
);

input clk;
input reset;
input pe_reset;
input start_mat_mul;
output done_mat_mul;
input [31:0] num_matrices_A; // Number of 16x16 matrices the input matrix can be divided into
input [31:0] num_matrices_B; // Number of 16x16 matrices the weight matrix can be divided into
input [`AWIDTH-1:0] address_mat_a;
input [`AWIDTH-1:0] address_mat_b;
input [`ADDR_STRIDE_WIDTH-1:0] address_stride_a;
input [`ADDR_STRIDE_WIDTH-1:0] address_stride_b;
input [`MAT_MUL_SIZE*`DWIDTH-1:0] a_data;
input [`MAT_MUL_SIZE*`DWIDTH-1:0] b_data;
input [`MAT_MUL_SIZE*`DWIDTH-1:0] a_data_in;
input [`MAT_MUL_SIZE*`DWIDTH-1:0] b_data_in;
input [`MAT_MUL_SIZE*`DWIDTH-1:0] c_data_in;
output [`MAT_MUL_SIZE*`DWIDTH-1:0] c_data_out;
output [`MAT_MUL_SIZE*`DWIDTH-1:0] a_data_out;
output [`MAT_MUL_SIZE*`DWIDTH-1:0] b_data_out;
output [`AWIDTH-1:0] a_addr;
output [`AWIDTH-1:0] b_addr;
output [`AWIDTH-1:0] c_addr;
output c_data_available;
output [`DWIDTH-1:0] matrixC15_0;
output [`DWIDTH-1:0] matrixC15_1;
output [`DWIDTH-1:0] matrixC15_2;
output [`DWIDTH-1:0] matrixC15_3;
output [`DWIDTH-1:0] matrixC15_4;
output [`DWIDTH-1:0] matrixC15_5;
output [`DWIDTH-1:0] matrixC15_6;
output [`DWIDTH-1:0] matrixC15_7;
output [`DWIDTH-1:0] matrixC15_8;
output [`DWIDTH-1:0] matrixC15_9;
output [`DWIDTH-1:0] matrixC15_10;
output [`DWIDTH-1:0] matrixC15_11;
output [`DWIDTH-1:0] matrixC15_12;
output [`DWIDTH-1:0] matrixC15_13;
output [`DWIDTH-1:0] matrixC15_14;
output [`DWIDTH-1:0] matrixC15_15;
input [`MASK_WIDTH-1:0] validity_mask_a_rows;
input [`MASK_WIDTH-1:0] validity_mask_a_cols_b_rows;
input [`MASK_WIDTH-1:0] validity_mask_b_cols;
input [31:0] a_loc;
input [31:0] b_loc;

//////////////////////////////////////////////////////////////////////////
// Logic for clock counting and when to assert done
//////////////////////////////////////////////////////////////////////////

reg done_mat_mul;
// This is set to 31 bits in accordance with the previous simulations.
// In general, a systolic multiplier takes 4*N-2+P cycles, where N is the size 
// of the matmul and P is the number of pipeline stages in the MAC block.
reg [31:0] clk_cnt;

// Finding out number of cycles to assert matmul done.
// When we have to save the outputs to accumulators, then we don't need to
// shift out data. So, we can assert done_mat_mul early.
// Note: the count expression used to contain "num_matrices_16x16*8", but 
// to avoid multiplication, we now use "num_matrices_16x16 << 3"
wire [31:0] clk_cnt_for_done;
assign clk_cnt_for_done = 
((num_matrices_A << (2*`LOG2_MAT_MUL_SIZE -1)) + 1  + `NUM_CYCLES_IN_MAC) ;  

always @(posedge clk) begin
if (reset || ~start_mat_mul) begin
    clk_cnt <= 0;
    done_mat_mul <= 0;
end
else if (clk_cnt == clk_cnt_for_done) begin
    done_mat_mul <= 1;
    clk_cnt <= clk_cnt + 1;
end
else if (done_mat_mul == 0) begin
    clk_cnt <= clk_cnt + 1;
end    
else begin
    done_mat_mul <= 0;
    clk_cnt <= clk_cnt + 1;
end
end

wire [`DWIDTH-1:0] a0_data;
wire [`DWIDTH-1:0] a1_data;
wire [`DWIDTH-1:0] a2_data;
wire [`DWIDTH-1:0] a3_data;
wire [`DWIDTH-1:0] a4_data;
wire [`DWIDTH-1:0] a5_data;
wire [`DWIDTH-1:0] a6_data;
wire [`DWIDTH-1:0] a7_data;
wire [`DWIDTH-1:0] a8_data;
wire [`DWIDTH-1:0] a9_data;
wire [`DWIDTH-1:0] a10_data;
wire [`DWIDTH-1:0] a11_data;
wire [`DWIDTH-1:0] a12_data;
wire [`DWIDTH-1:0] a13_data;
wire [`DWIDTH-1:0] a14_data;
wire [`DWIDTH-1:0] a15_data;
wire [`DWIDTH-1:0] b0_data;
wire [`DWIDTH-1:0] b1_data;
wire [`DWIDTH-1:0] b2_data;
wire [`DWIDTH-1:0] b3_data;
wire [`DWIDTH-1:0] b4_data;
wire [`DWIDTH-1:0] b5_data;
wire [`DWIDTH-1:0] b6_data;
wire [`DWIDTH-1:0] b7_data;
wire [`DWIDTH-1:0] b8_data;
wire [`DWIDTH-1:0] b9_data;
wire [`DWIDTH-1:0] b10_data;
wire [`DWIDTH-1:0] b11_data;
wire [`DWIDTH-1:0] b12_data;
wire [`DWIDTH-1:0] b13_data;
wire [`DWIDTH-1:0] b14_data;
wire [`DWIDTH-1:0] b15_data;
wire [`DWIDTH-1:0] a1_data_delayed_1;
wire [`DWIDTH-1:0] a2_data_delayed_1;
wire [`DWIDTH-1:0] a2_data_delayed_2;
wire [`DWIDTH-1:0] a3_data_delayed_1;
wire [`DWIDTH-1:0] a3_data_delayed_2;
wire [`DWIDTH-1:0] a3_data_delayed_3;
wire [`DWIDTH-1:0] a4_data_delayed_1;
wire [`DWIDTH-1:0] a4_data_delayed_2;
wire [`DWIDTH-1:0] a4_data_delayed_3;
wire [`DWIDTH-1:0] a4_data_delayed_4;
wire [`DWIDTH-1:0] a5_data_delayed_1;
wire [`DWIDTH-1:0] a5_data_delayed_2;
wire [`DWIDTH-1:0] a5_data_delayed_3;
wire [`DWIDTH-1:0] a5_data_delayed_4;
wire [`DWIDTH-1:0] a5_data_delayed_5;
wire [`DWIDTH-1:0] a6_data_delayed_1;
wire [`DWIDTH-1:0] a6_data_delayed_2;
wire [`DWIDTH-1:0] a6_data_delayed_3;
wire [`DWIDTH-1:0] a6_data_delayed_4;
wire [`DWIDTH-1:0] a6_data_delayed_5;
wire [`DWIDTH-1:0] a6_data_delayed_6;
wire [`DWIDTH-1:0] a7_data_delayed_1;
wire [`DWIDTH-1:0] a7_data_delayed_2;
wire [`DWIDTH-1:0] a7_data_delayed_3;
wire [`DWIDTH-1:0] a7_data_delayed_4;
wire [`DWIDTH-1:0] a7_data_delayed_5;
wire [`DWIDTH-1:0] a7_data_delayed_6;
wire [`DWIDTH-1:0] a7_data_delayed_7;
wire [`DWIDTH-1:0] a8_data_delayed_1;
wire [`DWIDTH-1:0] a8_data_delayed_2;
wire [`DWIDTH-1:0] a8_data_delayed_3;
wire [`DWIDTH-1:0] a8_data_delayed_4;
wire [`DWIDTH-1:0] a8_data_delayed_5;
wire [`DWIDTH-1:0] a8_data_delayed_6;
wire [`DWIDTH-1:0] a8_data_delayed_7;
wire [`DWIDTH-1:0] a8_data_delayed_8;
wire [`DWIDTH-1:0] a9_data_delayed_1;
wire [`DWIDTH-1:0] a9_data_delayed_2;
wire [`DWIDTH-1:0] a9_data_delayed_3;
wire [`DWIDTH-1:0] a9_data_delayed_4;
wire [`DWIDTH-1:0] a9_data_delayed_5;
wire [`DWIDTH-1:0] a9_data_delayed_6;
wire [`DWIDTH-1:0] a9_data_delayed_7;
wire [`DWIDTH-1:0] a9_data_delayed_8;
wire [`DWIDTH-1:0] a9_data_delayed_9;
wire [`DWIDTH-1:0] a10_data_delayed_1;
wire [`DWIDTH-1:0] a10_data_delayed_2;
wire [`DWIDTH-1:0] a10_data_delayed_3;
wire [`DWIDTH-1:0] a10_data_delayed_4;
wire [`DWIDTH-1:0] a10_data_delayed_5;
wire [`DWIDTH-1:0] a10_data_delayed_6;
wire [`DWIDTH-1:0] a10_data_delayed_7;
wire [`DWIDTH-1:0] a10_data_delayed_8;
wire [`DWIDTH-1:0] a10_data_delayed_9;
wire [`DWIDTH-1:0] a10_data_delayed_10;
wire [`DWIDTH-1:0] a11_data_delayed_1;
wire [`DWIDTH-1:0] a11_data_delayed_2;
wire [`DWIDTH-1:0] a11_data_delayed_3;
wire [`DWIDTH-1:0] a11_data_delayed_4;
wire [`DWIDTH-1:0] a11_data_delayed_5;
wire [`DWIDTH-1:0] a11_data_delayed_6;
wire [`DWIDTH-1:0] a11_data_delayed_7;
wire [`DWIDTH-1:0] a11_data_delayed_8;
wire [`DWIDTH-1:0] a11_data_delayed_9;
wire [`DWIDTH-1:0] a11_data_delayed_10;
wire [`DWIDTH-1:0] a11_data_delayed_11;
wire [`DWIDTH-1:0] a12_data_delayed_1;
wire [`DWIDTH-1:0] a12_data_delayed_2;
wire [`DWIDTH-1:0] a12_data_delayed_3;
wire [`DWIDTH-1:0] a12_data_delayed_4;
wire [`DWIDTH-1:0] a12_data_delayed_5;
wire [`DWIDTH-1:0] a12_data_delayed_6;
wire [`DWIDTH-1:0] a12_data_delayed_7;
wire [`DWIDTH-1:0] a12_data_delayed_8;
wire [`DWIDTH-1:0] a12_data_delayed_9;
wire [`DWIDTH-1:0] a12_data_delayed_10;
wire [`DWIDTH-1:0] a12_data_delayed_11;
wire [`DWIDTH-1:0] a12_data_delayed_12;
wire [`DWIDTH-1:0] a13_data_delayed_1;
wire [`DWIDTH-1:0] a13_data_delayed_2;
wire [`DWIDTH-1:0] a13_data_delayed_3;
wire [`DWIDTH-1:0] a13_data_delayed_4;
wire [`DWIDTH-1:0] a13_data_delayed_5;
wire [`DWIDTH-1:0] a13_data_delayed_6;
wire [`DWIDTH-1:0] a13_data_delayed_7;
wire [`DWIDTH-1:0] a13_data_delayed_8;
wire [`DWIDTH-1:0] a13_data_delayed_9;
wire [`DWIDTH-1:0] a13_data_delayed_10;
wire [`DWIDTH-1:0] a13_data_delayed_11;
wire [`DWIDTH-1:0] a13_data_delayed_12;
wire [`DWIDTH-1:0] a13_data_delayed_13;
wire [`DWIDTH-1:0] a14_data_delayed_1;
wire [`DWIDTH-1:0] a14_data_delayed_2;
wire [`DWIDTH-1:0] a14_data_delayed_3;
wire [`DWIDTH-1:0] a14_data_delayed_4;
wire [`DWIDTH-1:0] a14_data_delayed_5;
wire [`DWIDTH-1:0] a14_data_delayed_6;
wire [`DWIDTH-1:0] a14_data_delayed_7;
wire [`DWIDTH-1:0] a14_data_delayed_8;
wire [`DWIDTH-1:0] a14_data_delayed_9;
wire [`DWIDTH-1:0] a14_data_delayed_10;
wire [`DWIDTH-1:0] a14_data_delayed_11;
wire [`DWIDTH-1:0] a14_data_delayed_12;
wire [`DWIDTH-1:0] a14_data_delayed_13;
wire [`DWIDTH-1:0] a14_data_delayed_14;
wire [`DWIDTH-1:0] a15_data_delayed_1;
wire [`DWIDTH-1:0] a15_data_delayed_2;
wire [`DWIDTH-1:0] a15_data_delayed_3;
wire [`DWIDTH-1:0] a15_data_delayed_4;
wire [`DWIDTH-1:0] a15_data_delayed_5;
wire [`DWIDTH-1:0] a15_data_delayed_6;
wire [`DWIDTH-1:0] a15_data_delayed_7;
wire [`DWIDTH-1:0] a15_data_delayed_8;
wire [`DWIDTH-1:0] a15_data_delayed_9;
wire [`DWIDTH-1:0] a15_data_delayed_10;
wire [`DWIDTH-1:0] a15_data_delayed_11;
wire [`DWIDTH-1:0] a15_data_delayed_12;
wire [`DWIDTH-1:0] a15_data_delayed_13;
wire [`DWIDTH-1:0] a15_data_delayed_14;
wire [`DWIDTH-1:0] a15_data_delayed_15;
wire [`DWIDTH-1:0] b1_data_delayed_1;
wire [`DWIDTH-1:0] b2_data_delayed_1;
wire [`DWIDTH-1:0] b2_data_delayed_2;
wire [`DWIDTH-1:0] b3_data_delayed_1;
wire [`DWIDTH-1:0] b3_data_delayed_2;
wire [`DWIDTH-1:0] b3_data_delayed_3;
wire [`DWIDTH-1:0] b4_data_delayed_1;
wire [`DWIDTH-1:0] b4_data_delayed_2;
wire [`DWIDTH-1:0] b4_data_delayed_3;
wire [`DWIDTH-1:0] b4_data_delayed_4;
wire [`DWIDTH-1:0] b5_data_delayed_1;
wire [`DWIDTH-1:0] b5_data_delayed_2;
wire [`DWIDTH-1:0] b5_data_delayed_3;
wire [`DWIDTH-1:0] b5_data_delayed_4;
wire [`DWIDTH-1:0] b5_data_delayed_5;
wire [`DWIDTH-1:0] b6_data_delayed_1;
wire [`DWIDTH-1:0] b6_data_delayed_2;
wire [`DWIDTH-1:0] b6_data_delayed_3;
wire [`DWIDTH-1:0] b6_data_delayed_4;
wire [`DWIDTH-1:0] b6_data_delayed_5;
wire [`DWIDTH-1:0] b6_data_delayed_6;
wire [`DWIDTH-1:0] b7_data_delayed_1;
wire [`DWIDTH-1:0] b7_data_delayed_2;
wire [`DWIDTH-1:0] b7_data_delayed_3;
wire [`DWIDTH-1:0] b7_data_delayed_4;
wire [`DWIDTH-1:0] b7_data_delayed_5;
wire [`DWIDTH-1:0] b7_data_delayed_6;
wire [`DWIDTH-1:0] b7_data_delayed_7;
wire [`DWIDTH-1:0] b8_data_delayed_1;
wire [`DWIDTH-1:0] b8_data_delayed_2;
wire [`DWIDTH-1:0] b8_data_delayed_3;
wire [`DWIDTH-1:0] b8_data_delayed_4;
wire [`DWIDTH-1:0] b8_data_delayed_5;
wire [`DWIDTH-1:0] b8_data_delayed_6;
wire [`DWIDTH-1:0] b8_data_delayed_7;
wire [`DWIDTH-1:0] b8_data_delayed_8;
wire [`DWIDTH-1:0] b9_data_delayed_1;
wire [`DWIDTH-1:0] b9_data_delayed_2;
wire [`DWIDTH-1:0] b9_data_delayed_3;
wire [`DWIDTH-1:0] b9_data_delayed_4;
wire [`DWIDTH-1:0] b9_data_delayed_5;
wire [`DWIDTH-1:0] b9_data_delayed_6;
wire [`DWIDTH-1:0] b9_data_delayed_7;
wire [`DWIDTH-1:0] b9_data_delayed_8;
wire [`DWIDTH-1:0] b9_data_delayed_9;
wire [`DWIDTH-1:0] b10_data_delayed_1;
wire [`DWIDTH-1:0] b10_data_delayed_2;
wire [`DWIDTH-1:0] b10_data_delayed_3;
wire [`DWIDTH-1:0] b10_data_delayed_4;
wire [`DWIDTH-1:0] b10_data_delayed_5;
wire [`DWIDTH-1:0] b10_data_delayed_6;
wire [`DWIDTH-1:0] b10_data_delayed_7;
wire [`DWIDTH-1:0] b10_data_delayed_8;
wire [`DWIDTH-1:0] b10_data_delayed_9;
wire [`DWIDTH-1:0] b10_data_delayed_10;
wire [`DWIDTH-1:0] b11_data_delayed_1;
wire [`DWIDTH-1:0] b11_data_delayed_2;
wire [`DWIDTH-1:0] b11_data_delayed_3;
wire [`DWIDTH-1:0] b11_data_delayed_4;
wire [`DWIDTH-1:0] b11_data_delayed_5;
wire [`DWIDTH-1:0] b11_data_delayed_6;
wire [`DWIDTH-1:0] b11_data_delayed_7;
wire [`DWIDTH-1:0] b11_data_delayed_8;
wire [`DWIDTH-1:0] b11_data_delayed_9;
wire [`DWIDTH-1:0] b11_data_delayed_10;
wire [`DWIDTH-1:0] b11_data_delayed_11;
wire [`DWIDTH-1:0] b12_data_delayed_1;
wire [`DWIDTH-1:0] b12_data_delayed_2;
wire [`DWIDTH-1:0] b12_data_delayed_3;
wire [`DWIDTH-1:0] b12_data_delayed_4;
wire [`DWIDTH-1:0] b12_data_delayed_5;
wire [`DWIDTH-1:0] b12_data_delayed_6;
wire [`DWIDTH-1:0] b12_data_delayed_7;
wire [`DWIDTH-1:0] b12_data_delayed_8;
wire [`DWIDTH-1:0] b12_data_delayed_9;
wire [`DWIDTH-1:0] b12_data_delayed_10;
wire [`DWIDTH-1:0] b12_data_delayed_11;
wire [`DWIDTH-1:0] b12_data_delayed_12;
wire [`DWIDTH-1:0] b13_data_delayed_1;
wire [`DWIDTH-1:0] b13_data_delayed_2;
wire [`DWIDTH-1:0] b13_data_delayed_3;
wire [`DWIDTH-1:0] b13_data_delayed_4;
wire [`DWIDTH-1:0] b13_data_delayed_5;
wire [`DWIDTH-1:0] b13_data_delayed_6;
wire [`DWIDTH-1:0] b13_data_delayed_7;
wire [`DWIDTH-1:0] b13_data_delayed_8;
wire [`DWIDTH-1:0] b13_data_delayed_9;
wire [`DWIDTH-1:0] b13_data_delayed_10;
wire [`DWIDTH-1:0] b13_data_delayed_11;
wire [`DWIDTH-1:0] b13_data_delayed_12;
wire [`DWIDTH-1:0] b13_data_delayed_13;
wire [`DWIDTH-1:0] b14_data_delayed_1;
wire [`DWIDTH-1:0] b14_data_delayed_2;
wire [`DWIDTH-1:0] b14_data_delayed_3;
wire [`DWIDTH-1:0] b14_data_delayed_4;
wire [`DWIDTH-1:0] b14_data_delayed_5;
wire [`DWIDTH-1:0] b14_data_delayed_6;
wire [`DWIDTH-1:0] b14_data_delayed_7;
wire [`DWIDTH-1:0] b14_data_delayed_8;
wire [`DWIDTH-1:0] b14_data_delayed_9;
wire [`DWIDTH-1:0] b14_data_delayed_10;
wire [`DWIDTH-1:0] b14_data_delayed_11;
wire [`DWIDTH-1:0] b14_data_delayed_12;
wire [`DWIDTH-1:0] b14_data_delayed_13;
wire [`DWIDTH-1:0] b14_data_delayed_14;
wire [`DWIDTH-1:0] b15_data_delayed_1;
wire [`DWIDTH-1:0] b15_data_delayed_2;
wire [`DWIDTH-1:0] b15_data_delayed_3;
wire [`DWIDTH-1:0] b15_data_delayed_4;
wire [`DWIDTH-1:0] b15_data_delayed_5;
wire [`DWIDTH-1:0] b15_data_delayed_6;
wire [`DWIDTH-1:0] b15_data_delayed_7;
wire [`DWIDTH-1:0] b15_data_delayed_8;
wire [`DWIDTH-1:0] b15_data_delayed_9;
wire [`DWIDTH-1:0] b15_data_delayed_10;
wire [`DWIDTH-1:0] b15_data_delayed_11;
wire [`DWIDTH-1:0] b15_data_delayed_12;
wire [`DWIDTH-1:0] b15_data_delayed_13;
wire [`DWIDTH-1:0] b15_data_delayed_14;
wire [`DWIDTH-1:0] b15_data_delayed_15;

reg b_data_sel; // MUX select for Ping-Pong buffers containing the weights in the matmul
reg b_data_valid_ping;
reg b_data_valid_pong;

always @ (posedge clk) begin
	if ((clk_cnt >= 16'd1 && clk_cnt <= 16'd8)||(clk_cnt >= 16'd17 && clk_cnt <= 16'd24))
		b_data_valid_pong <= 1'b1;
	else 
		b_data_valid_pong <= 1'b0;
end

always @ (posedge clk) begin
	if ((clk_cnt >= 16'd9 && clk_cnt <= 16'd16))
		b_data_valid_ping <= 1'b1;
	else 
		b_data_valid_ping <= 1'b0;
end

always @ (posedge clk) begin
	if ((clk_cnt >= 16'd10 && clk_cnt <= 16'd17)||(clk_cnt >= 16'd26 && clk_cnt <= 16'd33))
		b_data_sel <= 1'b1;
	else 
		b_data_sel <= 1'b0;
end

//////////////////////////////////////////////////////////////////////////
// Instantiation of systolic data setup
//////////////////////////////////////////////////////////////////////////
systolic_data_setup u_systolic_data_setup(
    .clk(clk),
    .reset(reset),
    .start_mat_mul(start_mat_mul),
    .a_addr(a_addr),
    .b_addr(b_addr),
    .address_mat_a(address_mat_a),
    .address_mat_b(address_mat_b),
    .address_stride_a(address_stride_a),
    .address_stride_b(address_stride_b),
    .a_data(a_data),
    .b_data(b_data),
    .clk_cnt(clk_cnt),
    .a0_data(a0_data),
    .a1_data_delayed_1(a1_data_delayed_1),
    .a2_data_delayed_2(a2_data_delayed_2),
    .a3_data_delayed_3(a3_data_delayed_3),
    .a4_data_delayed_4(a4_data_delayed_4),
    .a5_data_delayed_5(a5_data_delayed_5),
    .a6_data_delayed_6(a6_data_delayed_6),
    .a7_data_delayed_7(a7_data_delayed_7),
    .a8_data_delayed_8(a8_data_delayed_8),
    .a9_data_delayed_9(a9_data_delayed_9),
    .a10_data_delayed_10(a10_data_delayed_10),
    .a11_data_delayed_11(a11_data_delayed_11),
    .a12_data_delayed_12(a12_data_delayed_12),
    .a13_data_delayed_13(a13_data_delayed_13),
    .a14_data_delayed_14(a14_data_delayed_14),
    .a15_data_delayed_15(a15_data_delayed_15),
    .b0_data(b0_data),
    .b1_data_delayed_1(b1_data_delayed_1),
    .b2_data_delayed_2(b2_data_delayed_2),
    .b3_data_delayed_3(b3_data_delayed_3),
    .b4_data_delayed_4(b4_data_delayed_4),
    .b5_data_delayed_5(b5_data_delayed_5),
    .b6_data_delayed_6(b6_data_delayed_6),
    .b7_data_delayed_7(b7_data_delayed_7),
    .b8_data_delayed_8(b8_data_delayed_8),
    .b9_data_delayed_9(b9_data_delayed_9),
    .b10_data_delayed_10(b10_data_delayed_10),
    .b11_data_delayed_11(b11_data_delayed_11),
    .b12_data_delayed_12(b12_data_delayed_12),
    .b13_data_delayed_13(b13_data_delayed_13),
    .b14_data_delayed_14(b14_data_delayed_14),
    .b15_data_delayed_15(b15_data_delayed_15),
    .validity_mask_a_rows(validity_mask_a_rows),
    .validity_mask_a_cols_b_rows(validity_mask_a_cols_b_rows),
    .validity_mask_b_cols(validity_mask_b_cols),
    .num_matrices_A(num_matrices_A),
    .num_matrices_B(num_matrices_B),
    .a_loc(a_loc),
    .b_loc(b_loc)
);

//////////////////////////////////////////////////////////////////////////
// Logic to mux data_in coming from neighboring matmuls
//////////////////////////////////////////////////////////////////////////
wire [`DWIDTH-1:0] a0;
wire [`DWIDTH-1:0] a1;
wire [`DWIDTH-1:0] a2;
wire [`DWIDTH-1:0] a3;
wire [`DWIDTH-1:0] a4;
wire [`DWIDTH-1:0] a5;
wire [`DWIDTH-1:0] a6;
wire [`DWIDTH-1:0] a7;
wire [`DWIDTH-1:0] a8;
wire [`DWIDTH-1:0] a9;
wire [`DWIDTH-1:0] a10;
wire [`DWIDTH-1:0] a11;
wire [`DWIDTH-1:0] a12;
wire [`DWIDTH-1:0] a13;
wire [`DWIDTH-1:0] a14;
wire [`DWIDTH-1:0] a15;
wire [`DWIDTH-1:0] b0;
wire [`DWIDTH-1:0] b1;
wire [`DWIDTH-1:0] b2;
wire [`DWIDTH-1:0] b3;
wire [`DWIDTH-1:0] b4;
wire [`DWIDTH-1:0] b5;
wire [`DWIDTH-1:0] b6;
wire [`DWIDTH-1:0] b7;
wire [`DWIDTH-1:0] b8;
wire [`DWIDTH-1:0] b9;
wire [`DWIDTH-1:0] b10;
wire [`DWIDTH-1:0] b11;
wire [`DWIDTH-1:0] b12;
wire [`DWIDTH-1:0] b13;
wire [`DWIDTH-1:0] b14;
wire [`DWIDTH-1:0] b15;
wire [`DWIDTH-1:0] c0;
wire [`DWIDTH-1:0] c1;
wire [`DWIDTH-1:0] c2;
wire [`DWIDTH-1:0] c3;
wire [`DWIDTH-1:0] c4;
wire [`DWIDTH-1:0] c5;
wire [`DWIDTH-1:0] c6;
wire [`DWIDTH-1:0] c7;
wire [`DWIDTH-1:0] c8;
wire [`DWIDTH-1:0] c9;
wire [`DWIDTH-1:0] c10;
wire [`DWIDTH-1:0] c11;
wire [`DWIDTH-1:0] c12;
wire [`DWIDTH-1:0] c13;
wire [`DWIDTH-1:0] c14;
wire [`DWIDTH-1:0] c15;

wire [`DWIDTH-1:0] a0_data_in;
wire [`DWIDTH-1:0] a1_data_in;
wire [`DWIDTH-1:0] a2_data_in;
wire [`DWIDTH-1:0] a3_data_in;
wire [`DWIDTH-1:0] a4_data_in;
wire [`DWIDTH-1:0] a5_data_in;
wire [`DWIDTH-1:0] a6_data_in;
wire [`DWIDTH-1:0] a7_data_in;
wire [`DWIDTH-1:0] a8_data_in;
wire [`DWIDTH-1:0] a9_data_in;
wire [`DWIDTH-1:0] a10_data_in;
wire [`DWIDTH-1:0] a11_data_in;
wire [`DWIDTH-1:0] a12_data_in;
wire [`DWIDTH-1:0] a13_data_in;
wire [`DWIDTH-1:0] a14_data_in;
wire [`DWIDTH-1:0] a15_data_in;
assign a0_data_in = a_data_in[`DWIDTH-1:0];
assign a1_data_in = a_data_in[2*`DWIDTH-1:1*`DWIDTH];
assign a2_data_in = a_data_in[3*`DWIDTH-1:2*`DWIDTH];
assign a3_data_in = a_data_in[4*`DWIDTH-1:3*`DWIDTH];
assign a4_data_in = a_data_in[5*`DWIDTH-1:4*`DWIDTH];
assign a5_data_in = a_data_in[6*`DWIDTH-1:5*`DWIDTH];
assign a6_data_in = a_data_in[7*`DWIDTH-1:6*`DWIDTH];
assign a7_data_in = a_data_in[8*`DWIDTH-1:7*`DWIDTH];
assign a8_data_in = a_data_in[9*`DWIDTH-1:8*`DWIDTH];
assign a9_data_in = a_data_in[10*`DWIDTH-1:9*`DWIDTH];
assign a10_data_in = a_data_in[11*`DWIDTH-1:10*`DWIDTH];
assign a11_data_in = a_data_in[12*`DWIDTH-1:11*`DWIDTH];
assign a12_data_in = a_data_in[13*`DWIDTH-1:12*`DWIDTH];
assign a13_data_in = a_data_in[14*`DWIDTH-1:13*`DWIDTH];
assign a14_data_in = a_data_in[15*`DWIDTH-1:14*`DWIDTH];
assign a15_data_in = a_data_in[16*`DWIDTH-1:15*`DWIDTH];

wire [`DWIDTH-1:0] b0_data_in;
wire [`DWIDTH-1:0] b1_data_in;
wire [`DWIDTH-1:0] b2_data_in;
wire [`DWIDTH-1:0] b3_data_in;
wire [`DWIDTH-1:0] b4_data_in;
wire [`DWIDTH-1:0] b5_data_in;
wire [`DWIDTH-1:0] b6_data_in;
wire [`DWIDTH-1:0] b7_data_in;
wire [`DWIDTH-1:0] b8_data_in;
wire [`DWIDTH-1:0] b9_data_in;
wire [`DWIDTH-1:0] b10_data_in;
wire [`DWIDTH-1:0] b11_data_in;
wire [`DWIDTH-1:0] b12_data_in;
wire [`DWIDTH-1:0] b13_data_in;
wire [`DWIDTH-1:0] b14_data_in;
wire [`DWIDTH-1:0] b15_data_in;
assign b0_data_in = b_data_in[`DWIDTH-1:0];
assign b1_data_in = b_data_in[2*`DWIDTH-1:1*`DWIDTH];
assign b2_data_in = b_data_in[3*`DWIDTH-1:2*`DWIDTH];
assign b3_data_in = b_data_in[4*`DWIDTH-1:3*`DWIDTH];
assign b4_data_in = b_data_in[5*`DWIDTH-1:4*`DWIDTH];
assign b5_data_in = b_data_in[6*`DWIDTH-1:5*`DWIDTH];
assign b6_data_in = b_data_in[7*`DWIDTH-1:6*`DWIDTH];
assign b7_data_in = b_data_in[8*`DWIDTH-1:7*`DWIDTH];
assign b8_data_in = b_data_in[9*`DWIDTH-1:8*`DWIDTH];
assign b9_data_in = b_data_in[10*`DWIDTH-1:9*`DWIDTH];
assign b10_data_in = b_data_in[11*`DWIDTH-1:10*`DWIDTH];
assign b11_data_in = b_data_in[12*`DWIDTH-1:11*`DWIDTH];
assign b12_data_in = b_data_in[13*`DWIDTH-1:12*`DWIDTH];
assign b13_data_in = b_data_in[14*`DWIDTH-1:13*`DWIDTH];
assign b14_data_in = b_data_in[15*`DWIDTH-1:14*`DWIDTH];
assign b15_data_in = b_data_in[16*`DWIDTH-1:15*`DWIDTH];

// If b_loc is 0, that means this matmul block is on the top-row of the
// final large matmul. In that case, b will take inputs from mem.
// If b_loc != 0, that means this matmul block is not on the top-row of the
// final large matmul. In that case, b will take inputs from the matmul on top
// of this one.
assign a0 = (b_loc==0) ? a0_data           : a0_data_in;
assign a1 = (b_loc==0) ? a1_data_delayed_1 : a1_data_in;
assign a2 = (b_loc==0) ? a2_data_delayed_2 : a2_data_in;
assign a3 = (b_loc==0) ? a3_data_delayed_3 : a3_data_in;
assign a4 = (b_loc==0) ? a4_data_delayed_4 : a4_data_in;
assign a5 = (b_loc==0) ? a5_data_delayed_5 : a5_data_in;
assign a6 = (b_loc==0) ? a6_data_delayed_6 : a6_data_in;
assign a7 = (b_loc==0) ? a7_data_delayed_7 : a7_data_in;
assign a8 = (b_loc==0) ? a8_data_delayed_8 : a8_data_in;
assign a9 = (b_loc==0) ? a9_data_delayed_9 : a9_data_in;
assign a10 = (b_loc==0) ? a10_data_delayed_10 : a10_data_in;
assign a11 = (b_loc==0) ? a11_data_delayed_11 : a11_data_in;
assign a12 = (b_loc==0) ? a12_data_delayed_12 : a12_data_in;
assign a13 = (b_loc==0) ? a13_data_delayed_13 : a13_data_in;
assign a14 = (b_loc==0) ? a14_data_delayed_14 : a14_data_in;
assign a15 = (b_loc==0) ? a15_data_delayed_15 : a15_data_in;

/// If a_loc is 0, that means this matmul block is on the left-col of the
// final large matmul. In that case, a will take inputs from mem.
// If a_loc != 0, that means this matmul block is not on the left-col of the
// final large matmul. In that case, a will take inputs from the matmul on left
// of this one.
assign b0 = (a_loc==0) ? b0_data           : b0_data_in;
assign b1 = (a_loc==0) ? b1_data_delayed_1 : b1_data_in;
assign b2 = (a_loc==0) ? b2_data_delayed_2 : b2_data_in;
assign b3 = (a_loc==0) ? b3_data_delayed_3 : b3_data_in;
assign b4 = (a_loc==0) ? b4_data_delayed_4 : b4_data_in;
assign b5 = (a_loc==0) ? b5_data_delayed_5 : b5_data_in;
assign b6 = (a_loc==0) ? b6_data_delayed_6 : b6_data_in;
assign b7 = (a_loc==0) ? b7_data_delayed_7 : b7_data_in;
assign b8 = (a_loc==0) ? b8_data_delayed_8 : b8_data_in;
assign b9 = (a_loc==0) ? b9_data_delayed_9 : b9_data_in;
assign b10 = (a_loc==0) ? b10_data_delayed_10 : b10_data_in;
assign b11 = (a_loc==0) ? b11_data_delayed_11 : b11_data_in;
assign b12 = (a_loc==0) ? b12_data_delayed_12 : b12_data_in;
assign b13 = (a_loc==0) ? b13_data_delayed_13 : b13_data_in;
assign b14 = (a_loc==0) ? b14_data_delayed_14 : b14_data_in;
assign b15 = (a_loc==0) ? b15_data_delayed_15 : b15_data_in;

assign c0 = c_data_in[`DWIDTH-1:0];
assign c1 = c_data_in[2*`DWIDTH-1:1*`DWIDTH];
assign c2 = c_data_in[3*`DWIDTH-1:2*`DWIDTH];
assign c3 = c_data_in[4*`DWIDTH-1:3*`DWIDTH];
assign c4 = c_data_in[5*`DWIDTH-1:4*`DWIDTH];
assign c5 = c_data_in[6*`DWIDTH-1:5*`DWIDTH];
assign c6 = c_data_in[7*`DWIDTH-1:6*`DWIDTH];
assign c7 = c_data_in[8*`DWIDTH-1:7*`DWIDTH];
assign c8 = c_data_in[9*`DWIDTH-1:8*`DWIDTH];
assign c9 = c_data_in[10*`DWIDTH-1:9*`DWIDTH];
assign c10 = c_data_in[11*`DWIDTH-1:10*`DWIDTH];
assign c11 = c_data_in[12*`DWIDTH-1:11*`DWIDTH];
assign c12 = c_data_in[13*`DWIDTH-1:12*`DWIDTH];
assign c13 = c_data_in[14*`DWIDTH-1:13*`DWIDTH];
assign c14 = c_data_in[15*`DWIDTH-1:14*`DWIDTH];
assign c15 = c_data_in[16*`DWIDTH-1:15*`DWIDTH];

wire [`DWIDTH-1:0] matrixC0_0;
wire [`DWIDTH-1:0] matrixC0_1;
wire [`DWIDTH-1:0] matrixC0_2;
wire [`DWIDTH-1:0] matrixC0_3;
wire [`DWIDTH-1:0] matrixC0_4;
wire [`DWIDTH-1:0] matrixC0_5;
wire [`DWIDTH-1:0] matrixC0_6;
wire [`DWIDTH-1:0] matrixC0_7;
wire [`DWIDTH-1:0] matrixC0_8;
wire [`DWIDTH-1:0] matrixC0_9;
wire [`DWIDTH-1:0] matrixC0_10;
wire [`DWIDTH-1:0] matrixC0_11;
wire [`DWIDTH-1:0] matrixC0_12;
wire [`DWIDTH-1:0] matrixC0_13;
wire [`DWIDTH-1:0] matrixC0_14;
wire [`DWIDTH-1:0] matrixC0_15;
wire [`DWIDTH-1:0] matrixC1_0;
wire [`DWIDTH-1:0] matrixC1_1;
wire [`DWIDTH-1:0] matrixC1_2;
wire [`DWIDTH-1:0] matrixC1_3;
wire [`DWIDTH-1:0] matrixC1_4;
wire [`DWIDTH-1:0] matrixC1_5;
wire [`DWIDTH-1:0] matrixC1_6;
wire [`DWIDTH-1:0] matrixC1_7;
wire [`DWIDTH-1:0] matrixC1_8;
wire [`DWIDTH-1:0] matrixC1_9;
wire [`DWIDTH-1:0] matrixC1_10;
wire [`DWIDTH-1:0] matrixC1_11;
wire [`DWIDTH-1:0] matrixC1_12;
wire [`DWIDTH-1:0] matrixC1_13;
wire [`DWIDTH-1:0] matrixC1_14;
wire [`DWIDTH-1:0] matrixC1_15;
wire [`DWIDTH-1:0] matrixC2_0;
wire [`DWIDTH-1:0] matrixC2_1;
wire [`DWIDTH-1:0] matrixC2_2;
wire [`DWIDTH-1:0] matrixC2_3;
wire [`DWIDTH-1:0] matrixC2_4;
wire [`DWIDTH-1:0] matrixC2_5;
wire [`DWIDTH-1:0] matrixC2_6;
wire [`DWIDTH-1:0] matrixC2_7;
wire [`DWIDTH-1:0] matrixC2_8;
wire [`DWIDTH-1:0] matrixC2_9;
wire [`DWIDTH-1:0] matrixC2_10;
wire [`DWIDTH-1:0] matrixC2_11;
wire [`DWIDTH-1:0] matrixC2_12;
wire [`DWIDTH-1:0] matrixC2_13;
wire [`DWIDTH-1:0] matrixC2_14;
wire [`DWIDTH-1:0] matrixC2_15;
wire [`DWIDTH-1:0] matrixC3_0;
wire [`DWIDTH-1:0] matrixC3_1;
wire [`DWIDTH-1:0] matrixC3_2;
wire [`DWIDTH-1:0] matrixC3_3;
wire [`DWIDTH-1:0] matrixC3_4;
wire [`DWIDTH-1:0] matrixC3_5;
wire [`DWIDTH-1:0] matrixC3_6;
wire [`DWIDTH-1:0] matrixC3_7;
wire [`DWIDTH-1:0] matrixC3_8;
wire [`DWIDTH-1:0] matrixC3_9;
wire [`DWIDTH-1:0] matrixC3_10;
wire [`DWIDTH-1:0] matrixC3_11;
wire [`DWIDTH-1:0] matrixC3_12;
wire [`DWIDTH-1:0] matrixC3_13;
wire [`DWIDTH-1:0] matrixC3_14;
wire [`DWIDTH-1:0] matrixC3_15;
wire [`DWIDTH-1:0] matrixC4_0;
wire [`DWIDTH-1:0] matrixC4_1;
wire [`DWIDTH-1:0] matrixC4_2;
wire [`DWIDTH-1:0] matrixC4_3;
wire [`DWIDTH-1:0] matrixC4_4;
wire [`DWIDTH-1:0] matrixC4_5;
wire [`DWIDTH-1:0] matrixC4_6;
wire [`DWIDTH-1:0] matrixC4_7;
wire [`DWIDTH-1:0] matrixC4_8;
wire [`DWIDTH-1:0] matrixC4_9;
wire [`DWIDTH-1:0] matrixC4_10;
wire [`DWIDTH-1:0] matrixC4_11;
wire [`DWIDTH-1:0] matrixC4_12;
wire [`DWIDTH-1:0] matrixC4_13;
wire [`DWIDTH-1:0] matrixC4_14;
wire [`DWIDTH-1:0] matrixC4_15;
wire [`DWIDTH-1:0] matrixC5_0;
wire [`DWIDTH-1:0] matrixC5_1;
wire [`DWIDTH-1:0] matrixC5_2;
wire [`DWIDTH-1:0] matrixC5_3;
wire [`DWIDTH-1:0] matrixC5_4;
wire [`DWIDTH-1:0] matrixC5_5;
wire [`DWIDTH-1:0] matrixC5_6;
wire [`DWIDTH-1:0] matrixC5_7;
wire [`DWIDTH-1:0] matrixC5_8;
wire [`DWIDTH-1:0] matrixC5_9;
wire [`DWIDTH-1:0] matrixC5_10;
wire [`DWIDTH-1:0] matrixC5_11;
wire [`DWIDTH-1:0] matrixC5_12;
wire [`DWIDTH-1:0] matrixC5_13;
wire [`DWIDTH-1:0] matrixC5_14;
wire [`DWIDTH-1:0] matrixC5_15;
wire [`DWIDTH-1:0] matrixC6_0;
wire [`DWIDTH-1:0] matrixC6_1;
wire [`DWIDTH-1:0] matrixC6_2;
wire [`DWIDTH-1:0] matrixC6_3;
wire [`DWIDTH-1:0] matrixC6_4;
wire [`DWIDTH-1:0] matrixC6_5;
wire [`DWIDTH-1:0] matrixC6_6;
wire [`DWIDTH-1:0] matrixC6_7;
wire [`DWIDTH-1:0] matrixC6_8;
wire [`DWIDTH-1:0] matrixC6_9;
wire [`DWIDTH-1:0] matrixC6_10;
wire [`DWIDTH-1:0] matrixC6_11;
wire [`DWIDTH-1:0] matrixC6_12;
wire [`DWIDTH-1:0] matrixC6_13;
wire [`DWIDTH-1:0] matrixC6_14;
wire [`DWIDTH-1:0] matrixC6_15;
wire [`DWIDTH-1:0] matrixC7_0;
wire [`DWIDTH-1:0] matrixC7_1;
wire [`DWIDTH-1:0] matrixC7_2;
wire [`DWIDTH-1:0] matrixC7_3;
wire [`DWIDTH-1:0] matrixC7_4;
wire [`DWIDTH-1:0] matrixC7_5;
wire [`DWIDTH-1:0] matrixC7_6;
wire [`DWIDTH-1:0] matrixC7_7;
wire [`DWIDTH-1:0] matrixC7_8;
wire [`DWIDTH-1:0] matrixC7_9;
wire [`DWIDTH-1:0] matrixC7_10;
wire [`DWIDTH-1:0] matrixC7_11;
wire [`DWIDTH-1:0] matrixC7_12;
wire [`DWIDTH-1:0] matrixC7_13;
wire [`DWIDTH-1:0] matrixC7_14;
wire [`DWIDTH-1:0] matrixC7_15;
wire [`DWIDTH-1:0] matrixC8_0;
wire [`DWIDTH-1:0] matrixC8_1;
wire [`DWIDTH-1:0] matrixC8_2;
wire [`DWIDTH-1:0] matrixC8_3;
wire [`DWIDTH-1:0] matrixC8_4;
wire [`DWIDTH-1:0] matrixC8_5;
wire [`DWIDTH-1:0] matrixC8_6;
wire [`DWIDTH-1:0] matrixC8_7;
wire [`DWIDTH-1:0] matrixC8_8;
wire [`DWIDTH-1:0] matrixC8_9;
wire [`DWIDTH-1:0] matrixC8_10;
wire [`DWIDTH-1:0] matrixC8_11;
wire [`DWIDTH-1:0] matrixC8_12;
wire [`DWIDTH-1:0] matrixC8_13;
wire [`DWIDTH-1:0] matrixC8_14;
wire [`DWIDTH-1:0] matrixC8_15;
wire [`DWIDTH-1:0] matrixC9_0;
wire [`DWIDTH-1:0] matrixC9_1;
wire [`DWIDTH-1:0] matrixC9_2;
wire [`DWIDTH-1:0] matrixC9_3;
wire [`DWIDTH-1:0] matrixC9_4;
wire [`DWIDTH-1:0] matrixC9_5;
wire [`DWIDTH-1:0] matrixC9_6;
wire [`DWIDTH-1:0] matrixC9_7;
wire [`DWIDTH-1:0] matrixC9_8;
wire [`DWIDTH-1:0] matrixC9_9;
wire [`DWIDTH-1:0] matrixC9_10;
wire [`DWIDTH-1:0] matrixC9_11;
wire [`DWIDTH-1:0] matrixC9_12;
wire [`DWIDTH-1:0] matrixC9_13;
wire [`DWIDTH-1:0] matrixC9_14;
wire [`DWIDTH-1:0] matrixC9_15;
wire [`DWIDTH-1:0] matrixC10_0;
wire [`DWIDTH-1:0] matrixC10_1;
wire [`DWIDTH-1:0] matrixC10_2;
wire [`DWIDTH-1:0] matrixC10_3;
wire [`DWIDTH-1:0] matrixC10_4;
wire [`DWIDTH-1:0] matrixC10_5;
wire [`DWIDTH-1:0] matrixC10_6;
wire [`DWIDTH-1:0] matrixC10_7;
wire [`DWIDTH-1:0] matrixC10_8;
wire [`DWIDTH-1:0] matrixC10_9;
wire [`DWIDTH-1:0] matrixC10_10;
wire [`DWIDTH-1:0] matrixC10_11;
wire [`DWIDTH-1:0] matrixC10_12;
wire [`DWIDTH-1:0] matrixC10_13;
wire [`DWIDTH-1:0] matrixC10_14;
wire [`DWIDTH-1:0] matrixC10_15;
wire [`DWIDTH-1:0] matrixC11_0;
wire [`DWIDTH-1:0] matrixC11_1;
wire [`DWIDTH-1:0] matrixC11_2;
wire [`DWIDTH-1:0] matrixC11_3;
wire [`DWIDTH-1:0] matrixC11_4;
wire [`DWIDTH-1:0] matrixC11_5;
wire [`DWIDTH-1:0] matrixC11_6;
wire [`DWIDTH-1:0] matrixC11_7;
wire [`DWIDTH-1:0] matrixC11_8;
wire [`DWIDTH-1:0] matrixC11_9;
wire [`DWIDTH-1:0] matrixC11_10;
wire [`DWIDTH-1:0] matrixC11_11;
wire [`DWIDTH-1:0] matrixC11_12;
wire [`DWIDTH-1:0] matrixC11_13;
wire [`DWIDTH-1:0] matrixC11_14;
wire [`DWIDTH-1:0] matrixC11_15;
wire [`DWIDTH-1:0] matrixC12_0;
wire [`DWIDTH-1:0] matrixC12_1;
wire [`DWIDTH-1:0] matrixC12_2;
wire [`DWIDTH-1:0] matrixC12_3;
wire [`DWIDTH-1:0] matrixC12_4;
wire [`DWIDTH-1:0] matrixC12_5;
wire [`DWIDTH-1:0] matrixC12_6;
wire [`DWIDTH-1:0] matrixC12_7;
wire [`DWIDTH-1:0] matrixC12_8;
wire [`DWIDTH-1:0] matrixC12_9;
wire [`DWIDTH-1:0] matrixC12_10;
wire [`DWIDTH-1:0] matrixC12_11;
wire [`DWIDTH-1:0] matrixC12_12;
wire [`DWIDTH-1:0] matrixC12_13;
wire [`DWIDTH-1:0] matrixC12_14;
wire [`DWIDTH-1:0] matrixC12_15;
wire [`DWIDTH-1:0] matrixC13_0;
wire [`DWIDTH-1:0] matrixC13_1;
wire [`DWIDTH-1:0] matrixC13_2;
wire [`DWIDTH-1:0] matrixC13_3;
wire [`DWIDTH-1:0] matrixC13_4;
wire [`DWIDTH-1:0] matrixC13_5;
wire [`DWIDTH-1:0] matrixC13_6;
wire [`DWIDTH-1:0] matrixC13_7;
wire [`DWIDTH-1:0] matrixC13_8;
wire [`DWIDTH-1:0] matrixC13_9;
wire [`DWIDTH-1:0] matrixC13_10;
wire [`DWIDTH-1:0] matrixC13_11;
wire [`DWIDTH-1:0] matrixC13_12;
wire [`DWIDTH-1:0] matrixC13_13;
wire [`DWIDTH-1:0] matrixC13_14;
wire [`DWIDTH-1:0] matrixC13_15;
wire [`DWIDTH-1:0] matrixC14_0;
wire [`DWIDTH-1:0] matrixC14_1;
wire [`DWIDTH-1:0] matrixC14_2;
wire [`DWIDTH-1:0] matrixC14_3;
wire [`DWIDTH-1:0] matrixC14_4;
wire [`DWIDTH-1:0] matrixC14_5;
wire [`DWIDTH-1:0] matrixC14_6;
wire [`DWIDTH-1:0] matrixC14_7;
wire [`DWIDTH-1:0] matrixC14_8;
wire [`DWIDTH-1:0] matrixC14_9;
wire [`DWIDTH-1:0] matrixC14_10;
wire [`DWIDTH-1:0] matrixC14_11;
wire [`DWIDTH-1:0] matrixC14_12;
wire [`DWIDTH-1:0] matrixC14_13;
wire [`DWIDTH-1:0] matrixC14_14;
wire [`DWIDTH-1:0] matrixC14_15;
wire [`DWIDTH-1:0] matrixC15_0;
wire [`DWIDTH-1:0] matrixC15_1;
wire [`DWIDTH-1:0] matrixC15_2;
wire [`DWIDTH-1:0] matrixC15_3;
wire [`DWIDTH-1:0] matrixC15_4;
wire [`DWIDTH-1:0] matrixC15_5;
wire [`DWIDTH-1:0] matrixC15_6;
wire [`DWIDTH-1:0] matrixC15_7;
wire [`DWIDTH-1:0] matrixC15_8;
wire [`DWIDTH-1:0] matrixC15_9;
wire [`DWIDTH-1:0] matrixC15_10;
wire [`DWIDTH-1:0] matrixC15_11;
wire [`DWIDTH-1:0] matrixC15_12;
wire [`DWIDTH-1:0] matrixC15_13;
wire [`DWIDTH-1:0] matrixC15_14;
wire [`DWIDTH-1:0] matrixC15_15;

//////////////////////////////////////////////////////////////////////////
// Instantiations of the actual PEs
//////////////////////////////////////////////////////////////////////////
systolic_pe_matrix u_systolic_pe_matrix(
    .reset(reset),
    .clk(clk),
    .pe_reset(pe_reset),
    .b_data_sel(b_data_sel),
    .b_data_valid_ping(b_data_valid_ping), 
    .b_data_valid_pong(b_data_valid_pong),
    .a0(a0),
    .a1(a1),
    .a2(a2),
    .a3(a3),
    .a4(a4),
    .a5(a5),
    .a6(a6),
    .a7(a7),
    .a8(a8),
    .a9(a9),
    .a10(a10),
    .a11(a11),
    .a12(a12),
    .a13(a13),
    .a14(a14),
    .a15(a15),
    .b0(b0),
    .b1(b1),
    .b2(b2),
    .b3(b3),
    .b4(b4),
    .b5(b5),
    .b6(b6),
    .b7(b7),
    .b8(b8),
    .b9(b9),
    .b10(b10),
    .b11(b11),
    .b12(b12),
    .b13(b13),
    .b14(b14),
    .b15(b15),
    .c0(c0),
    .c1(c1),
    .c2(c2),
    .c3(c3),
    .c4(c4),
    .c5(c5),
    .c6(c6),
    .c7(c7),
    .c8(c8),
    .c9(c9),
    .c10(c10),
    .c11(c11),
    .c12(c12),
    .c13(c13),
    .c14(c14),
    .c15(c15),
    .matrixC0_0(matrixC0_0),
    .matrixC0_1(matrixC0_1),
    .matrixC0_2(matrixC0_2),
    .matrixC0_3(matrixC0_3),
    .matrixC0_4(matrixC0_4),
    .matrixC0_5(matrixC0_5),
    .matrixC0_6(matrixC0_6),
    .matrixC0_7(matrixC0_7),
    .matrixC0_8(matrixC0_8),
    .matrixC0_9(matrixC0_9),
    .matrixC0_10(matrixC0_10),
    .matrixC0_11(matrixC0_11),
    .matrixC0_12(matrixC0_12),
    .matrixC0_13(matrixC0_13),
    .matrixC0_14(matrixC0_14),
    .matrixC0_15(matrixC0_15),
    .matrixC1_0(matrixC1_0),
    .matrixC1_1(matrixC1_1),
    .matrixC1_2(matrixC1_2),
    .matrixC1_3(matrixC1_3),
    .matrixC1_4(matrixC1_4),
    .matrixC1_5(matrixC1_5),
    .matrixC1_6(matrixC1_6),
    .matrixC1_7(matrixC1_7),
    .matrixC1_8(matrixC1_8),
    .matrixC1_9(matrixC1_9),
    .matrixC1_10(matrixC1_10),
    .matrixC1_11(matrixC1_11),
    .matrixC1_12(matrixC1_12),
    .matrixC1_13(matrixC1_13),
    .matrixC1_14(matrixC1_14),
    .matrixC1_15(matrixC1_15),
    .matrixC2_0(matrixC2_0),
    .matrixC2_1(matrixC2_1),
    .matrixC2_2(matrixC2_2),
    .matrixC2_3(matrixC2_3),
    .matrixC2_4(matrixC2_4),
    .matrixC2_5(matrixC2_5),
    .matrixC2_6(matrixC2_6),
    .matrixC2_7(matrixC2_7),
    .matrixC2_8(matrixC2_8),
    .matrixC2_9(matrixC2_9),
    .matrixC2_10(matrixC2_10),
    .matrixC2_11(matrixC2_11),
    .matrixC2_12(matrixC2_12),
    .matrixC2_13(matrixC2_13),
    .matrixC2_14(matrixC2_14),
    .matrixC2_15(matrixC2_15),
    .matrixC3_0(matrixC3_0),
    .matrixC3_1(matrixC3_1),
    .matrixC3_2(matrixC3_2),
    .matrixC3_3(matrixC3_3),
    .matrixC3_4(matrixC3_4),
    .matrixC3_5(matrixC3_5),
    .matrixC3_6(matrixC3_6),
    .matrixC3_7(matrixC3_7),
    .matrixC3_8(matrixC3_8),
    .matrixC3_9(matrixC3_9),
    .matrixC3_10(matrixC3_10),
    .matrixC3_11(matrixC3_11),
    .matrixC3_12(matrixC3_12),
    .matrixC3_13(matrixC3_13),
    .matrixC3_14(matrixC3_14),
    .matrixC3_15(matrixC3_15),
    .matrixC4_0(matrixC4_0),
    .matrixC4_1(matrixC4_1),
    .matrixC4_2(matrixC4_2),
    .matrixC4_3(matrixC4_3),
    .matrixC4_4(matrixC4_4),
    .matrixC4_5(matrixC4_5),
    .matrixC4_6(matrixC4_6),
    .matrixC4_7(matrixC4_7),
    .matrixC4_8(matrixC4_8),
    .matrixC4_9(matrixC4_9),
    .matrixC4_10(matrixC4_10),
    .matrixC4_11(matrixC4_11),
    .matrixC4_12(matrixC4_12),
    .matrixC4_13(matrixC4_13),
    .matrixC4_14(matrixC4_14),
    .matrixC4_15(matrixC4_15),
    .matrixC5_0(matrixC5_0),
    .matrixC5_1(matrixC5_1),
    .matrixC5_2(matrixC5_2),
    .matrixC5_3(matrixC5_3),
    .matrixC5_4(matrixC5_4),
    .matrixC5_5(matrixC5_5),
    .matrixC5_6(matrixC5_6),
    .matrixC5_7(matrixC5_7),
    .matrixC5_8(matrixC5_8),
    .matrixC5_9(matrixC5_9),
    .matrixC5_10(matrixC5_10),
    .matrixC5_11(matrixC5_11),
    .matrixC5_12(matrixC5_12),
    .matrixC5_13(matrixC5_13),
    .matrixC5_14(matrixC5_14),
    .matrixC5_15(matrixC5_15),
    .matrixC6_0(matrixC6_0),
    .matrixC6_1(matrixC6_1),
    .matrixC6_2(matrixC6_2),
    .matrixC6_3(matrixC6_3),
    .matrixC6_4(matrixC6_4),
    .matrixC6_5(matrixC6_5),
    .matrixC6_6(matrixC6_6),
    .matrixC6_7(matrixC6_7),
    .matrixC6_8(matrixC6_8),
    .matrixC6_9(matrixC6_9),
    .matrixC6_10(matrixC6_10),
    .matrixC6_11(matrixC6_11),
    .matrixC6_12(matrixC6_12),
    .matrixC6_13(matrixC6_13),
    .matrixC6_14(matrixC6_14),
    .matrixC6_15(matrixC6_15),
    .matrixC7_0(matrixC7_0),
    .matrixC7_1(matrixC7_1),
    .matrixC7_2(matrixC7_2),
    .matrixC7_3(matrixC7_3),
    .matrixC7_4(matrixC7_4),
    .matrixC7_5(matrixC7_5),
    .matrixC7_6(matrixC7_6),
    .matrixC7_7(matrixC7_7),
    .matrixC7_8(matrixC7_8),
    .matrixC7_9(matrixC7_9),
    .matrixC7_10(matrixC7_10),
    .matrixC7_11(matrixC7_11),
    .matrixC7_12(matrixC7_12),
    .matrixC7_13(matrixC7_13),
    .matrixC7_14(matrixC7_14),
    .matrixC7_15(matrixC7_15),
    .matrixC8_0(matrixC8_0),
    .matrixC8_1(matrixC8_1),
    .matrixC8_2(matrixC8_2),
    .matrixC8_3(matrixC8_3),
    .matrixC8_4(matrixC8_4),
    .matrixC8_5(matrixC8_5),
    .matrixC8_6(matrixC8_6),
    .matrixC8_7(matrixC8_7),
    .matrixC8_8(matrixC8_8),
    .matrixC8_9(matrixC8_9),
    .matrixC8_10(matrixC8_10),
    .matrixC8_11(matrixC8_11),
    .matrixC8_12(matrixC8_12),
    .matrixC8_13(matrixC8_13),
    .matrixC8_14(matrixC8_14),
    .matrixC8_15(matrixC8_15),
    .matrixC9_0(matrixC9_0),
    .matrixC9_1(matrixC9_1),
    .matrixC9_2(matrixC9_2),
    .matrixC9_3(matrixC9_3),
    .matrixC9_4(matrixC9_4),
    .matrixC9_5(matrixC9_5),
    .matrixC9_6(matrixC9_6),
    .matrixC9_7(matrixC9_7),
    .matrixC9_8(matrixC9_8),
    .matrixC9_9(matrixC9_9),
    .matrixC9_10(matrixC9_10),
    .matrixC9_11(matrixC9_11),
    .matrixC9_12(matrixC9_12),
    .matrixC9_13(matrixC9_13),
    .matrixC9_14(matrixC9_14),
    .matrixC9_15(matrixC9_15),
    .matrixC10_0(matrixC10_0),
    .matrixC10_1(matrixC10_1),
    .matrixC10_2(matrixC10_2),
    .matrixC10_3(matrixC10_3),
    .matrixC10_4(matrixC10_4),
    .matrixC10_5(matrixC10_5),
    .matrixC10_6(matrixC10_6),
    .matrixC10_7(matrixC10_7),
    .matrixC10_8(matrixC10_8),
    .matrixC10_9(matrixC10_9),
    .matrixC10_10(matrixC10_10),
    .matrixC10_11(matrixC10_11),
    .matrixC10_12(matrixC10_12),
    .matrixC10_13(matrixC10_13),
    .matrixC10_14(matrixC10_14),
    .matrixC10_15(matrixC10_15),
    .matrixC11_0(matrixC11_0),
    .matrixC11_1(matrixC11_1),
    .matrixC11_2(matrixC11_2),
    .matrixC11_3(matrixC11_3),
    .matrixC11_4(matrixC11_4),
    .matrixC11_5(matrixC11_5),
    .matrixC11_6(matrixC11_6),
    .matrixC11_7(matrixC11_7),
    .matrixC11_8(matrixC11_8),
    .matrixC11_9(matrixC11_9),
    .matrixC11_10(matrixC11_10),
    .matrixC11_11(matrixC11_11),
    .matrixC11_12(matrixC11_12),
    .matrixC11_13(matrixC11_13),
    .matrixC11_14(matrixC11_14),
    .matrixC11_15(matrixC11_15),
    .matrixC12_0(matrixC12_0),
    .matrixC12_1(matrixC12_1),
    .matrixC12_2(matrixC12_2),
    .matrixC12_3(matrixC12_3),
    .matrixC12_4(matrixC12_4),
    .matrixC12_5(matrixC12_5),
    .matrixC12_6(matrixC12_6),
    .matrixC12_7(matrixC12_7),
    .matrixC12_8(matrixC12_8),
    .matrixC12_9(matrixC12_9),
    .matrixC12_10(matrixC12_10),
    .matrixC12_11(matrixC12_11),
    .matrixC12_12(matrixC12_12),
    .matrixC12_13(matrixC12_13),
    .matrixC12_14(matrixC12_14),
    .matrixC12_15(matrixC12_15),
    .matrixC13_0(matrixC13_0),
    .matrixC13_1(matrixC13_1),
    .matrixC13_2(matrixC13_2),
    .matrixC13_3(matrixC13_3),
    .matrixC13_4(matrixC13_4),
    .matrixC13_5(matrixC13_5),
    .matrixC13_6(matrixC13_6),
    .matrixC13_7(matrixC13_7),
    .matrixC13_8(matrixC13_8),
    .matrixC13_9(matrixC13_9),
    .matrixC13_10(matrixC13_10),
    .matrixC13_11(matrixC13_11),
    .matrixC13_12(matrixC13_12),
    .matrixC13_13(matrixC13_13),
    .matrixC13_14(matrixC13_14),
    .matrixC13_15(matrixC13_15),
    .matrixC14_0(matrixC14_0),
    .matrixC14_1(matrixC14_1),
    .matrixC14_2(matrixC14_2),
    .matrixC14_3(matrixC14_3),
    .matrixC14_4(matrixC14_4),
    .matrixC14_5(matrixC14_5),
    .matrixC14_6(matrixC14_6),
    .matrixC14_7(matrixC14_7),
    .matrixC14_8(matrixC14_8),
    .matrixC14_9(matrixC14_9),
    .matrixC14_10(matrixC14_10),
    .matrixC14_11(matrixC14_11),
    .matrixC14_12(matrixC14_12),
    .matrixC14_13(matrixC14_13),
    .matrixC14_14(matrixC14_14),
    .matrixC14_15(matrixC14_15),
    .matrixC15_0(matrixC15_0),
    .matrixC15_1(matrixC15_1),
    .matrixC15_2(matrixC15_2),
    .matrixC15_3(matrixC15_3),
    .matrixC15_4(matrixC15_4),
    .matrixC15_5(matrixC15_5),
    .matrixC15_6(matrixC15_6),
    .matrixC15_7(matrixC15_7),
    .matrixC15_8(matrixC15_8),
    .matrixC15_9(matrixC15_9),
    .matrixC15_10(matrixC15_10),
    .matrixC15_11(matrixC15_11),
    .matrixC15_12(matrixC15_12),
    .matrixC15_13(matrixC15_13),
    .matrixC15_14(matrixC15_14),
    .matrixC15_15(matrixC15_15),
    .a_data_out(a_data_out),
    .b_data_out(b_data_out)
);
  
wire c_data_available;
  
assign c_data_available = (clk_cnt > (`LOG2_MAT_MUL_SIZE-1+(`MAT_MUL_SIZE << 1)) & clk_cnt <= ((`LOG2_MAT_MUL_SIZE+(`MAT_MUL_SIZE << 1)) + (num_matrices_A << `LOG2_MAT_MUL_SIZE)-1));

endmodule

//////////////////////////////////////////////////////////////////////////
// Systolic data setup
//////////////////////////////////////////////////////////////////////////
module systolic_data_setup(
    clk,
    reset,
    start_mat_mul,
    a_addr,
    b_addr,
    address_mat_a,
    address_mat_b,
    address_stride_a,
    address_stride_b,
    a_data,
    b_data,
    clk_cnt,
    a0_data,
    a1_data_delayed_1,
    a2_data_delayed_2,
    a3_data_delayed_3,
    a4_data_delayed_4,
    a5_data_delayed_5,
    a6_data_delayed_6,
    a7_data_delayed_7,
    a8_data_delayed_8,
    a9_data_delayed_9,
    a10_data_delayed_10,
    a11_data_delayed_11,
    a12_data_delayed_12,
    a13_data_delayed_13,
    a14_data_delayed_14,
    a15_data_delayed_15,
    b0_data,
    b1_data_delayed_1,
    b2_data_delayed_2,
    b3_data_delayed_3,
    b4_data_delayed_4,
    b5_data_delayed_5,
    b6_data_delayed_6,
    b7_data_delayed_7,
    b8_data_delayed_8,
    b9_data_delayed_9,
    b10_data_delayed_10,
    b11_data_delayed_11,
    b12_data_delayed_12,
    b13_data_delayed_13,
    b14_data_delayed_14,
    b15_data_delayed_15,
    validity_mask_a_rows,
    validity_mask_a_cols_b_rows,
    validity_mask_b_cols,
    num_matrices_A,
    num_matrices_B,
    a_loc,
    b_loc 
);

input clk;
input reset;
input start_mat_mul;
output [`AWIDTH-1:0] a_addr;
output [`AWIDTH-1:0] b_addr;
input [`AWIDTH-1:0] address_mat_a;
input [`AWIDTH-1:0] address_mat_b;
input [`ADDR_STRIDE_WIDTH-1:0] address_stride_a;
input [`ADDR_STRIDE_WIDTH-1:0] address_stride_b;
input [`MAT_MUL_SIZE*`DWIDTH-1:0] a_data;
input [`MAT_MUL_SIZE*`DWIDTH-1:0] b_data;
input [31:0] clk_cnt;
output [`DWIDTH-1:0] a0_data;
output [`DWIDTH-1:0] a1_data_delayed_1;
output [`DWIDTH-1:0] a2_data_delayed_2;
output [`DWIDTH-1:0] a3_data_delayed_3;
output [`DWIDTH-1:0] a4_data_delayed_4;
output [`DWIDTH-1:0] a5_data_delayed_5;
output [`DWIDTH-1:0] a6_data_delayed_6;
output [`DWIDTH-1:0] a7_data_delayed_7;
output [`DWIDTH-1:0] a8_data_delayed_8;
output [`DWIDTH-1:0] a9_data_delayed_9;
output [`DWIDTH-1:0] a10_data_delayed_10;
output [`DWIDTH-1:0] a11_data_delayed_11;
output [`DWIDTH-1:0] a12_data_delayed_12;
output [`DWIDTH-1:0] a13_data_delayed_13;
output [`DWIDTH-1:0] a14_data_delayed_14;
output [`DWIDTH-1:0] a15_data_delayed_15;
output [`DWIDTH-1:0] b0_data;
output [`DWIDTH-1:0] b1_data_delayed_1;
output [`DWIDTH-1:0] b2_data_delayed_2;
output [`DWIDTH-1:0] b3_data_delayed_3;
output [`DWIDTH-1:0] b4_data_delayed_4;
output [`DWIDTH-1:0] b5_data_delayed_5;
output [`DWIDTH-1:0] b6_data_delayed_6;
output [`DWIDTH-1:0] b7_data_delayed_7;
output [`DWIDTH-1:0] b8_data_delayed_8;
output [`DWIDTH-1:0] b9_data_delayed_9;
output [`DWIDTH-1:0] b10_data_delayed_10;
output [`DWIDTH-1:0] b11_data_delayed_11;
output [`DWIDTH-1:0] b12_data_delayed_12;
output [`DWIDTH-1:0] b13_data_delayed_13;
output [`DWIDTH-1:0] b14_data_delayed_14;
output [`DWIDTH-1:0] b15_data_delayed_15;
input [`MASK_WIDTH-1:0] validity_mask_a_rows;
input [`MASK_WIDTH-1:0] validity_mask_a_cols_b_rows;
input [`MASK_WIDTH-1:0] validity_mask_b_cols;
input [31:0] num_matrices_A;
input [31:0] num_matrices_B;
input [31:0] a_loc;
input [31:0] b_loc;

wire [`DWIDTH-1:0] a0_data;
wire [`DWIDTH-1:0] a1_data;
wire [`DWIDTH-1:0] a2_data;
wire [`DWIDTH-1:0] a3_data;
wire [`DWIDTH-1:0] a4_data;
wire [`DWIDTH-1:0] a5_data;
wire [`DWIDTH-1:0] a6_data;
wire [`DWIDTH-1:0] a7_data;
wire [`DWIDTH-1:0] a8_data;
wire [`DWIDTH-1:0] a9_data;
wire [`DWIDTH-1:0] a10_data;
wire [`DWIDTH-1:0] a11_data;
wire [`DWIDTH-1:0] a12_data;
wire [`DWIDTH-1:0] a13_data;
wire [`DWIDTH-1:0] a14_data;
wire [`DWIDTH-1:0] a15_data;
wire [`DWIDTH-1:0] b0_data;
wire [`DWIDTH-1:0] b1_data;
wire [`DWIDTH-1:0] b2_data;
wire [`DWIDTH-1:0] b3_data;
wire [`DWIDTH-1:0] b4_data;
wire [`DWIDTH-1:0] b5_data;
wire [`DWIDTH-1:0] b6_data;
wire [`DWIDTH-1:0] b7_data;
wire [`DWIDTH-1:0] b8_data;
wire [`DWIDTH-1:0] b9_data;
wire [`DWIDTH-1:0] b10_data;
wire [`DWIDTH-1:0] b11_data;
wire [`DWIDTH-1:0] b12_data;
wire [`DWIDTH-1:0] b13_data;
wire [`DWIDTH-1:0] b14_data;
wire [`DWIDTH-1:0] b15_data;

wire a_data_valid; // flag that tells whether the data from memory is valid
wire b_data_valid; // flag that tells whether the data from memory is valid

//////////////////////////////////////////////////////////////////////////
// Logic to generate addresses to BRAM A
//////////////////////////////////////////////////////////////////////////

reg [`AWIDTH-1:0] a_addr;
reg a_mem_access; // flag that tells whether the matmul is trying to access memory or not
  
always @(posedge clk) begin     
if ((reset || ~start_mat_mul) || (clk_cnt >= (a_loc<<`LOG2_MAT_MUL_SIZE)+`MAT_MUL_SIZE+(num_matrices_A << `LOG2_MAT_MUL_SIZE))) begin
        a_addr <= address_mat_a-address_stride_a;
        a_mem_access <= 0; 
end
else if ((clk_cnt >= (a_loc<<`LOG2_MAT_MUL_SIZE)+`MAT_MUL_SIZE) && (clk_cnt < (a_loc<<`LOG2_MAT_MUL_SIZE)+`MAT_MUL_SIZE+(num_matrices_A << `LOG2_MAT_MUL_SIZE))) begin
        a_addr <= a_addr + address_stride_a;
        a_mem_access <= 1;
end
end


//////////////////////////////////////////////////////////////////////////
// Logic to generate valid signals for data coming from BRAM A
//////////////////////////////////////////////////////////////////////////

reg [31:0] a_mem_access_counter;

always @(posedge clk) begin
    if (reset || ~start_mat_mul) begin
        a_mem_access_counter <= 0;
    end
    else if (a_mem_access == 1) begin
        a_mem_access_counter <= a_mem_access_counter + 1;  
    end
    else begin
        a_mem_access_counter <= 0;
    end
end
  
assign a_data_valid = 
       ((validity_mask_a_cols_b_rows[0]==1'b0 && a_mem_access_counter==1) ||
        (validity_mask_a_cols_b_rows[1]==1'b0 && a_mem_access_counter==2) ||
        (validity_mask_a_cols_b_rows[2]==1'b0 && a_mem_access_counter==3) ||
        (validity_mask_a_cols_b_rows[3]==1'b0 && a_mem_access_counter==4) ||
        (validity_mask_a_cols_b_rows[4]==1'b0 && a_mem_access_counter==5) ||
        (validity_mask_a_cols_b_rows[5]==1'b0 && a_mem_access_counter==6) ||
        (validity_mask_a_cols_b_rows[6]==1'b0 && a_mem_access_counter==7) ||
        (validity_mask_a_cols_b_rows[7]==1'b0 && a_mem_access_counter==8) ||
        (validity_mask_a_cols_b_rows[8]==1'b0 && a_mem_access_counter==9) ||
        (validity_mask_a_cols_b_rows[9]==1'b0 && a_mem_access_counter==10) ||
        (validity_mask_a_cols_b_rows[10]==1'b0 && a_mem_access_counter==11) ||
        (validity_mask_a_cols_b_rows[11]==1'b0 && a_mem_access_counter==12) ||
        (validity_mask_a_cols_b_rows[12]==1'b0 && a_mem_access_counter==13) ||
        (validity_mask_a_cols_b_rows[13]==1'b0 && a_mem_access_counter==14) ||
        (validity_mask_a_cols_b_rows[14]==1'b0 && a_mem_access_counter==15) ||
        (validity_mask_a_cols_b_rows[15]==1'b0 && a_mem_access_counter==16)) ?
        1'b0 : (a_mem_access_counter >= `MEM_ACCESS_LATENCY);

//////////////////////////////////////////////////////////////////////////
// Logic to delay certain parts of the data received from BRAM A (systolic data setup)
//////////////////////////////////////////////////////////////////////////

// Slice data into chunks and qualify it with whether it is valid or not
assign a0_data = a_data[`DWIDTH-1:0] & {`DWIDTH{a_data_valid}} & {`DWIDTH{validity_mask_a_rows[0]}};
assign a1_data = a_data[2*`DWIDTH-1:1*`DWIDTH] & {`DWIDTH{a_data_valid}} & {`DWIDTH{validity_mask_a_rows[1]}};
assign a2_data = a_data[3*`DWIDTH-1:2*`DWIDTH] & {`DWIDTH{a_data_valid}} & {`DWIDTH{validity_mask_a_rows[2]}};
assign a3_data = a_data[4*`DWIDTH-1:3*`DWIDTH] & {`DWIDTH{a_data_valid}} & {`DWIDTH{validity_mask_a_rows[3]}};
assign a4_data = a_data[5*`DWIDTH-1:4*`DWIDTH] & {`DWIDTH{a_data_valid}} & {`DWIDTH{validity_mask_a_rows[4]}};
assign a5_data = a_data[6*`DWIDTH-1:5*`DWIDTH] & {`DWIDTH{a_data_valid}} & {`DWIDTH{validity_mask_a_rows[5]}};
assign a6_data = a_data[7*`DWIDTH-1:6*`DWIDTH] & {`DWIDTH{a_data_valid}} & {`DWIDTH{validity_mask_a_rows[6]}};
assign a7_data = a_data[8*`DWIDTH-1:7*`DWIDTH] & {`DWIDTH{a_data_valid}} & {`DWIDTH{validity_mask_a_rows[7]}};
assign a8_data = a_data[9*`DWIDTH-1:8*`DWIDTH] & {`DWIDTH{a_data_valid}} & {`DWIDTH{validity_mask_a_rows[8]}};
assign a9_data = a_data[10*`DWIDTH-1:9*`DWIDTH] & {`DWIDTH{a_data_valid}} & {`DWIDTH{validity_mask_a_rows[9]}};
assign a10_data = a_data[11*`DWIDTH-1:10*`DWIDTH] & {`DWIDTH{a_data_valid}} & {`DWIDTH{validity_mask_a_rows[10]}};
assign a11_data = a_data[12*`DWIDTH-1:11*`DWIDTH] & {`DWIDTH{a_data_valid}} & {`DWIDTH{validity_mask_a_rows[11]}};
assign a12_data = a_data[13*`DWIDTH-1:12*`DWIDTH] & {`DWIDTH{a_data_valid}} & {`DWIDTH{validity_mask_a_rows[12]}};
assign a13_data = a_data[14*`DWIDTH-1:13*`DWIDTH] & {`DWIDTH{a_data_valid}} & {`DWIDTH{validity_mask_a_rows[13]}};
assign a14_data = a_data[15*`DWIDTH-1:14*`DWIDTH] & {`DWIDTH{a_data_valid}} & {`DWIDTH{validity_mask_a_rows[14]}};
assign a15_data = a_data[16*`DWIDTH-1:15*`DWIDTH] & {`DWIDTH{a_data_valid}} & {`DWIDTH{validity_mask_a_rows[15]}};

// For larger matmuls, more such delaying flops will be needed
reg [`DWIDTH-1:0] a1_data_delayed_1;
reg [`DWIDTH-1:0] a2_data_delayed_1;
reg [`DWIDTH-1:0] a2_data_delayed_2;
reg [`DWIDTH-1:0] a3_data_delayed_1;
reg [`DWIDTH-1:0] a3_data_delayed_2;
reg [`DWIDTH-1:0] a3_data_delayed_3;
reg [`DWIDTH-1:0] a4_data_delayed_1;
reg [`DWIDTH-1:0] a4_data_delayed_2;
reg [`DWIDTH-1:0] a4_data_delayed_3;
reg [`DWIDTH-1:0] a4_data_delayed_4;
reg [`DWIDTH-1:0] a5_data_delayed_1;
reg [`DWIDTH-1:0] a5_data_delayed_2;
reg [`DWIDTH-1:0] a5_data_delayed_3;
reg [`DWIDTH-1:0] a5_data_delayed_4;
reg [`DWIDTH-1:0] a5_data_delayed_5;
reg [`DWIDTH-1:0] a6_data_delayed_1;
reg [`DWIDTH-1:0] a6_data_delayed_2;
reg [`DWIDTH-1:0] a6_data_delayed_3;
reg [`DWIDTH-1:0] a6_data_delayed_4;
reg [`DWIDTH-1:0] a6_data_delayed_5;
reg [`DWIDTH-1:0] a6_data_delayed_6;
reg [`DWIDTH-1:0] a7_data_delayed_1;
reg [`DWIDTH-1:0] a7_data_delayed_2;
reg [`DWIDTH-1:0] a7_data_delayed_3;
reg [`DWIDTH-1:0] a7_data_delayed_4;
reg [`DWIDTH-1:0] a7_data_delayed_5;
reg [`DWIDTH-1:0] a7_data_delayed_6;
reg [`DWIDTH-1:0] a7_data_delayed_7;
reg [`DWIDTH-1:0] a8_data_delayed_1;
reg [`DWIDTH-1:0] a8_data_delayed_2;
reg [`DWIDTH-1:0] a8_data_delayed_3;
reg [`DWIDTH-1:0] a8_data_delayed_4;
reg [`DWIDTH-1:0] a8_data_delayed_5;
reg [`DWIDTH-1:0] a8_data_delayed_6;
reg [`DWIDTH-1:0] a8_data_delayed_7;
reg [`DWIDTH-1:0] a8_data_delayed_8;
reg [`DWIDTH-1:0] a9_data_delayed_1;
reg [`DWIDTH-1:0] a9_data_delayed_2;
reg [`DWIDTH-1:0] a9_data_delayed_3;
reg [`DWIDTH-1:0] a9_data_delayed_4;
reg [`DWIDTH-1:0] a9_data_delayed_5;
reg [`DWIDTH-1:0] a9_data_delayed_6;
reg [`DWIDTH-1:0] a9_data_delayed_7;
reg [`DWIDTH-1:0] a9_data_delayed_8;
reg [`DWIDTH-1:0] a9_data_delayed_9;
reg [`DWIDTH-1:0] a10_data_delayed_1;
reg [`DWIDTH-1:0] a10_data_delayed_2;
reg [`DWIDTH-1:0] a10_data_delayed_3;
reg [`DWIDTH-1:0] a10_data_delayed_4;
reg [`DWIDTH-1:0] a10_data_delayed_5;
reg [`DWIDTH-1:0] a10_data_delayed_6;
reg [`DWIDTH-1:0] a10_data_delayed_7;
reg [`DWIDTH-1:0] a10_data_delayed_8;
reg [`DWIDTH-1:0] a10_data_delayed_9;
reg [`DWIDTH-1:0] a10_data_delayed_10;
reg [`DWIDTH-1:0] a11_data_delayed_1;
reg [`DWIDTH-1:0] a11_data_delayed_2;
reg [`DWIDTH-1:0] a11_data_delayed_3;
reg [`DWIDTH-1:0] a11_data_delayed_4;
reg [`DWIDTH-1:0] a11_data_delayed_5;
reg [`DWIDTH-1:0] a11_data_delayed_6;
reg [`DWIDTH-1:0] a11_data_delayed_7;
reg [`DWIDTH-1:0] a11_data_delayed_8;
reg [`DWIDTH-1:0] a11_data_delayed_9;
reg [`DWIDTH-1:0] a11_data_delayed_10;
reg [`DWIDTH-1:0] a11_data_delayed_11;
reg [`DWIDTH-1:0] a12_data_delayed_1;
reg [`DWIDTH-1:0] a12_data_delayed_2;
reg [`DWIDTH-1:0] a12_data_delayed_3;
reg [`DWIDTH-1:0] a12_data_delayed_4;
reg [`DWIDTH-1:0] a12_data_delayed_5;
reg [`DWIDTH-1:0] a12_data_delayed_6;
reg [`DWIDTH-1:0] a12_data_delayed_7;
reg [`DWIDTH-1:0] a12_data_delayed_8;
reg [`DWIDTH-1:0] a12_data_delayed_9;
reg [`DWIDTH-1:0] a12_data_delayed_10;
reg [`DWIDTH-1:0] a12_data_delayed_11;
reg [`DWIDTH-1:0] a12_data_delayed_12;
reg [`DWIDTH-1:0] a13_data_delayed_1;
reg [`DWIDTH-1:0] a13_data_delayed_2;
reg [`DWIDTH-1:0] a13_data_delayed_3;
reg [`DWIDTH-1:0] a13_data_delayed_4;
reg [`DWIDTH-1:0] a13_data_delayed_5;
reg [`DWIDTH-1:0] a13_data_delayed_6;
reg [`DWIDTH-1:0] a13_data_delayed_7;
reg [`DWIDTH-1:0] a13_data_delayed_8;
reg [`DWIDTH-1:0] a13_data_delayed_9;
reg [`DWIDTH-1:0] a13_data_delayed_10;
reg [`DWIDTH-1:0] a13_data_delayed_11;
reg [`DWIDTH-1:0] a13_data_delayed_12;
reg [`DWIDTH-1:0] a13_data_delayed_13;
reg [`DWIDTH-1:0] a14_data_delayed_1;
reg [`DWIDTH-1:0] a14_data_delayed_2;
reg [`DWIDTH-1:0] a14_data_delayed_3;
reg [`DWIDTH-1:0] a14_data_delayed_4;
reg [`DWIDTH-1:0] a14_data_delayed_5;
reg [`DWIDTH-1:0] a14_data_delayed_6;
reg [`DWIDTH-1:0] a14_data_delayed_7;
reg [`DWIDTH-1:0] a14_data_delayed_8;
reg [`DWIDTH-1:0] a14_data_delayed_9;
reg [`DWIDTH-1:0] a14_data_delayed_10;
reg [`DWIDTH-1:0] a14_data_delayed_11;
reg [`DWIDTH-1:0] a14_data_delayed_12;
reg [`DWIDTH-1:0] a14_data_delayed_13;
reg [`DWIDTH-1:0] a14_data_delayed_14;
reg [`DWIDTH-1:0] a15_data_delayed_1;
reg [`DWIDTH-1:0] a15_data_delayed_2;
reg [`DWIDTH-1:0] a15_data_delayed_3;
reg [`DWIDTH-1:0] a15_data_delayed_4;
reg [`DWIDTH-1:0] a15_data_delayed_5;
reg [`DWIDTH-1:0] a15_data_delayed_6;
reg [`DWIDTH-1:0] a15_data_delayed_7;
reg [`DWIDTH-1:0] a15_data_delayed_8;
reg [`DWIDTH-1:0] a15_data_delayed_9;
reg [`DWIDTH-1:0] a15_data_delayed_10;
reg [`DWIDTH-1:0] a15_data_delayed_11;
reg [`DWIDTH-1:0] a15_data_delayed_12;
reg [`DWIDTH-1:0] a15_data_delayed_13;
reg [`DWIDTH-1:0] a15_data_delayed_14;
reg [`DWIDTH-1:0] a15_data_delayed_15;

always @(posedge clk) begin
  if (reset || ~start_mat_mul || clk_cnt==0) begin
    a1_data_delayed_1 <= 0;
    a2_data_delayed_1 <= 0;
    a2_data_delayed_2 <= 0;
    a3_data_delayed_1 <= 0;
    a3_data_delayed_2 <= 0;
    a3_data_delayed_3 <= 0;
    a4_data_delayed_1 <= 0;
    a4_data_delayed_2 <= 0;
    a4_data_delayed_3 <= 0;
    a4_data_delayed_4 <= 0;
    a5_data_delayed_1 <= 0;
    a5_data_delayed_2 <= 0;
    a5_data_delayed_3 <= 0;
    a5_data_delayed_4 <= 0;
    a5_data_delayed_5 <= 0;
    a6_data_delayed_1 <= 0;
    a6_data_delayed_2 <= 0;
    a6_data_delayed_3 <= 0;
    a6_data_delayed_4 <= 0;
    a6_data_delayed_5 <= 0;
    a6_data_delayed_6 <= 0;
    a7_data_delayed_1 <= 0;
    a7_data_delayed_2 <= 0;
    a7_data_delayed_3 <= 0;
    a7_data_delayed_4 <= 0;
    a7_data_delayed_5 <= 0;
    a7_data_delayed_6 <= 0;
    a7_data_delayed_7 <= 0;
    a8_data_delayed_1 <= 0;
    a8_data_delayed_2 <= 0;
    a8_data_delayed_3 <= 0;
    a8_data_delayed_4 <= 0;
    a8_data_delayed_5 <= 0;
    a8_data_delayed_6 <= 0;
    a8_data_delayed_7 <= 0;
    a8_data_delayed_8 <= 0;
    a9_data_delayed_1 <= 0;
    a9_data_delayed_2 <= 0;
    a9_data_delayed_3 <= 0;
    a9_data_delayed_4 <= 0;
    a9_data_delayed_5 <= 0;
    a9_data_delayed_6 <= 0;
    a9_data_delayed_7 <= 0;
    a9_data_delayed_8 <= 0;
    a9_data_delayed_9 <= 0;
    a10_data_delayed_1 <= 0;
    a10_data_delayed_2 <= 0;
    a10_data_delayed_3 <= 0;
    a10_data_delayed_4 <= 0;
    a10_data_delayed_5 <= 0;
    a10_data_delayed_6 <= 0;
    a10_data_delayed_7 <= 0;
    a10_data_delayed_8 <= 0;
    a10_data_delayed_9 <= 0;
    a10_data_delayed_10 <= 0;
    a11_data_delayed_1 <= 0;
    a11_data_delayed_2 <= 0;
    a11_data_delayed_3 <= 0;
    a11_data_delayed_4 <= 0;
    a11_data_delayed_5 <= 0;
    a11_data_delayed_6 <= 0;
    a11_data_delayed_7 <= 0;
    a11_data_delayed_8 <= 0;
    a11_data_delayed_9 <= 0;
    a11_data_delayed_10 <= 0;
    a11_data_delayed_11 <= 0;
    a12_data_delayed_1 <= 0;
    a12_data_delayed_2 <= 0;
    a12_data_delayed_3 <= 0;
    a12_data_delayed_4 <= 0;
    a12_data_delayed_5 <= 0;
    a12_data_delayed_6 <= 0;
    a12_data_delayed_7 <= 0;
    a12_data_delayed_8 <= 0;
    a12_data_delayed_9 <= 0;
    a12_data_delayed_10 <= 0;
    a12_data_delayed_11 <= 0;
    a12_data_delayed_12 <= 0;
    a13_data_delayed_1 <= 0;
    a13_data_delayed_2 <= 0;
    a13_data_delayed_3 <= 0;
    a13_data_delayed_4 <= 0;
    a13_data_delayed_5 <= 0;
    a13_data_delayed_6 <= 0;
    a13_data_delayed_7 <= 0;
    a13_data_delayed_8 <= 0;
    a13_data_delayed_9 <= 0;
    a13_data_delayed_10 <= 0;
    a13_data_delayed_11 <= 0;
    a13_data_delayed_12 <= 0;
    a13_data_delayed_13 <= 0;
    a14_data_delayed_1 <= 0;
    a14_data_delayed_2 <= 0;
    a14_data_delayed_3 <= 0;
    a14_data_delayed_4 <= 0;
    a14_data_delayed_5 <= 0;
    a14_data_delayed_6 <= 0;
    a14_data_delayed_7 <= 0;
    a14_data_delayed_8 <= 0;
    a14_data_delayed_9 <= 0;
    a14_data_delayed_10 <= 0;
    a14_data_delayed_11 <= 0;
    a14_data_delayed_12 <= 0;
    a14_data_delayed_13 <= 0;
    a14_data_delayed_14 <= 0;
    a15_data_delayed_1 <= 0;
    a15_data_delayed_2 <= 0;
    a15_data_delayed_3 <= 0;
    a15_data_delayed_4 <= 0;
    a15_data_delayed_5 <= 0;
    a15_data_delayed_6 <= 0;
    a15_data_delayed_7 <= 0;
    a15_data_delayed_8 <= 0;
    a15_data_delayed_9 <= 0;
    a15_data_delayed_10 <= 0;
    a15_data_delayed_11 <= 0;
    a15_data_delayed_12 <= 0;
    a15_data_delayed_13 <= 0;
    a15_data_delayed_14 <= 0;
    a15_data_delayed_15 <= 0;
  end
  else begin
    a1_data_delayed_1 <= a1_data;
    a2_data_delayed_1 <= a2_data;
    a2_data_delayed_2 <= a2_data_delayed_1;
    a3_data_delayed_1 <= a3_data;
    a3_data_delayed_2 <= a3_data_delayed_1;
    a3_data_delayed_3 <= a3_data_delayed_2;
    a4_data_delayed_1 <= a4_data;
    a4_data_delayed_2 <= a4_data_delayed_1;
    a4_data_delayed_3 <= a4_data_delayed_2;
    a4_data_delayed_4 <= a4_data_delayed_3;
    a5_data_delayed_1 <= a5_data;
    a5_data_delayed_2 <= a5_data_delayed_1;
    a5_data_delayed_3 <= a5_data_delayed_2;
    a5_data_delayed_4 <= a5_data_delayed_3;
    a5_data_delayed_5 <= a5_data_delayed_4;
    a6_data_delayed_1 <= a6_data;
    a6_data_delayed_2 <= a6_data_delayed_1;
    a6_data_delayed_3 <= a6_data_delayed_2;
    a6_data_delayed_4 <= a6_data_delayed_3;
    a6_data_delayed_5 <= a6_data_delayed_4;
    a6_data_delayed_6 <= a6_data_delayed_5;
    a7_data_delayed_1 <= a7_data;
    a7_data_delayed_2 <= a7_data_delayed_1;
    a7_data_delayed_3 <= a7_data_delayed_2;
    a7_data_delayed_4 <= a7_data_delayed_3;
    a7_data_delayed_5 <= a7_data_delayed_4;
    a7_data_delayed_6 <= a7_data_delayed_5;
    a7_data_delayed_7 <= a7_data_delayed_6;
    a8_data_delayed_1 <= a8_data;
    a8_data_delayed_2 <= a8_data_delayed_1;
    a8_data_delayed_3 <= a8_data_delayed_2;
    a8_data_delayed_4 <= a8_data_delayed_3;
    a8_data_delayed_5 <= a8_data_delayed_4;
    a8_data_delayed_6 <= a8_data_delayed_5;
    a8_data_delayed_7 <= a8_data_delayed_6;
    a8_data_delayed_8 <= a8_data_delayed_7;
    a9_data_delayed_1 <= a9_data;
    a9_data_delayed_2 <= a9_data_delayed_1;
    a9_data_delayed_3 <= a9_data_delayed_2;
    a9_data_delayed_4 <= a9_data_delayed_3;
    a9_data_delayed_5 <= a9_data_delayed_4;
    a9_data_delayed_6 <= a9_data_delayed_5;
    a9_data_delayed_7 <= a9_data_delayed_6;
    a9_data_delayed_8 <= a9_data_delayed_7;
    a9_data_delayed_9 <= a9_data_delayed_8;
    a10_data_delayed_1 <= a10_data;
    a10_data_delayed_2 <= a10_data_delayed_1;
    a10_data_delayed_3 <= a10_data_delayed_2;
    a10_data_delayed_4 <= a10_data_delayed_3;
    a10_data_delayed_5 <= a10_data_delayed_4;
    a10_data_delayed_6 <= a10_data_delayed_5;
    a10_data_delayed_7 <= a10_data_delayed_6;
    a10_data_delayed_8 <= a10_data_delayed_7;
    a10_data_delayed_9 <= a10_data_delayed_8;
    a10_data_delayed_10 <= a10_data_delayed_9;
    a11_data_delayed_1 <= a11_data;
    a11_data_delayed_2 <= a11_data_delayed_1;
    a11_data_delayed_3 <= a11_data_delayed_2;
    a11_data_delayed_4 <= a11_data_delayed_3;
    a11_data_delayed_5 <= a11_data_delayed_4;
    a11_data_delayed_6 <= a11_data_delayed_5;
    a11_data_delayed_7 <= a11_data_delayed_6;
    a11_data_delayed_8 <= a11_data_delayed_7;
    a11_data_delayed_9 <= a11_data_delayed_8;
    a11_data_delayed_10 <= a11_data_delayed_9;
    a11_data_delayed_11 <= a11_data_delayed_10;
    a12_data_delayed_1 <= a12_data;
    a12_data_delayed_2 <= a12_data_delayed_1;
    a12_data_delayed_3 <= a12_data_delayed_2;
    a12_data_delayed_4 <= a12_data_delayed_3;
    a12_data_delayed_5 <= a12_data_delayed_4;
    a12_data_delayed_6 <= a12_data_delayed_5;
    a12_data_delayed_7 <= a12_data_delayed_6;
    a12_data_delayed_8 <= a12_data_delayed_7;
    a12_data_delayed_9 <= a12_data_delayed_8;
    a12_data_delayed_10 <= a12_data_delayed_9;
    a12_data_delayed_11 <= a12_data_delayed_10;
    a12_data_delayed_12 <= a12_data_delayed_11;
    a13_data_delayed_1 <= a13_data;
    a13_data_delayed_2 <= a13_data_delayed_1;
    a13_data_delayed_3 <= a13_data_delayed_2;
    a13_data_delayed_4 <= a13_data_delayed_3;
    a13_data_delayed_5 <= a13_data_delayed_4;
    a13_data_delayed_6 <= a13_data_delayed_5;
    a13_data_delayed_7 <= a13_data_delayed_6;
    a13_data_delayed_8 <= a13_data_delayed_7;
    a13_data_delayed_9 <= a13_data_delayed_8;
    a13_data_delayed_10 <= a13_data_delayed_9;
    a13_data_delayed_11 <= a13_data_delayed_10;
    a13_data_delayed_12 <= a13_data_delayed_11;
    a13_data_delayed_13 <= a13_data_delayed_12;
    a14_data_delayed_1 <= a14_data;
    a14_data_delayed_2 <= a14_data_delayed_1;
    a14_data_delayed_3 <= a14_data_delayed_2;
    a14_data_delayed_4 <= a14_data_delayed_3;
    a14_data_delayed_5 <= a14_data_delayed_4;
    a14_data_delayed_6 <= a14_data_delayed_5;
    a14_data_delayed_7 <= a14_data_delayed_6;
    a14_data_delayed_8 <= a14_data_delayed_7;
    a14_data_delayed_9 <= a14_data_delayed_8;
    a14_data_delayed_10 <= a14_data_delayed_9;
    a14_data_delayed_11 <= a14_data_delayed_10;
    a14_data_delayed_12 <= a14_data_delayed_11;
    a14_data_delayed_13 <= a14_data_delayed_12;
    a14_data_delayed_14 <= a14_data_delayed_13;
    a15_data_delayed_1 <= a15_data;
    a15_data_delayed_2 <= a15_data_delayed_1;
    a15_data_delayed_3 <= a15_data_delayed_2;
    a15_data_delayed_4 <= a15_data_delayed_3;
    a15_data_delayed_5 <= a15_data_delayed_4;
    a15_data_delayed_6 <= a15_data_delayed_5;
    a15_data_delayed_7 <= a15_data_delayed_6;
    a15_data_delayed_8 <= a15_data_delayed_7;
    a15_data_delayed_9 <= a15_data_delayed_8;
    a15_data_delayed_10 <= a15_data_delayed_9;
    a15_data_delayed_11 <= a15_data_delayed_10;
    a15_data_delayed_12 <= a15_data_delayed_11;
    a15_data_delayed_13 <= a15_data_delayed_12;
    a15_data_delayed_14 <= a15_data_delayed_13;
    a15_data_delayed_15 <= a15_data_delayed_14;
  end
end

//////////////////////////////////////////////////////////////////////////
// Logic to generate addresses to BRAM B
//////////////////////////////////////////////////////////////////////////

reg [`AWIDTH-1:0] b_addr;
reg b_mem_access; // flag that tells whether the matmul is trying to access memory or not
 
always @(posedge clk) begin  
    if ((reset || ~start_mat_mul) || (clk_cnt >= (b_loc<<`LOG2_MAT_MUL_SIZE)+num_matrices_B << `LOG2_MAT_MUL_SIZE)) begin
        b_addr <= address_mat_b - address_stride_b;
        b_mem_access <= 0;
    end 
    else if ((clk_cnt >= (b_loc<<`LOG2_MAT_MUL_SIZE)) && (clk_cnt < (b_loc<<`LOG2_MAT_MUL_SIZE)+num_matrices_B << `LOG2_MAT_MUL_SIZE)) begin
        b_addr <= b_addr + address_stride_b;
        b_mem_access <= 1;
    end
end  

//////////////////////////////////////////////////////////////////////////
// Logic to generate valid signals for data coming from BRAM B
//////////////////////////////////////////////////////////////////////////

reg [7:0] b_mem_access_counter;

always @(posedge clk) begin
    if (reset || ~start_mat_mul) begin
        b_mem_access_counter <= 0;
    end
    else if (b_mem_access == 1) begin
        b_mem_access_counter <= b_mem_access_counter + 1;  
    end
    else begin
        b_mem_access_counter <= 0;
    end
end

assign b_data_valid = 
       ((validity_mask_a_cols_b_rows[0]==1'b0 && b_mem_access_counter==1) ||
        (validity_mask_a_cols_b_rows[1]==1'b0 && b_mem_access_counter==2) ||
        (validity_mask_a_cols_b_rows[2]==1'b0 && b_mem_access_counter==3) ||
        (validity_mask_a_cols_b_rows[3]==1'b0 && b_mem_access_counter==4) ||
        (validity_mask_a_cols_b_rows[4]==1'b0 && b_mem_access_counter==5) ||
        (validity_mask_a_cols_b_rows[5]==1'b0 && b_mem_access_counter==6) ||
        (validity_mask_a_cols_b_rows[6]==1'b0 && b_mem_access_counter==7) ||
        (validity_mask_a_cols_b_rows[7]==1'b0 && b_mem_access_counter==8) ||
        (validity_mask_a_cols_b_rows[8]==1'b0 && b_mem_access_counter==9) ||
        (validity_mask_a_cols_b_rows[9]==1'b0 && b_mem_access_counter==10) ||
        (validity_mask_a_cols_b_rows[10]==1'b0 && b_mem_access_counter==11) ||
        (validity_mask_a_cols_b_rows[11]==1'b0 && b_mem_access_counter==12) ||
        (validity_mask_a_cols_b_rows[12]==1'b0 && b_mem_access_counter==13) ||
        (validity_mask_a_cols_b_rows[13]==1'b0 && b_mem_access_counter==14) ||
        (validity_mask_a_cols_b_rows[14]==1'b0 && b_mem_access_counter==15) ||
        (validity_mask_a_cols_b_rows[15]==1'b0 && b_mem_access_counter==16)) ?
        1'b0 : (b_mem_access_counter >= `MEM_ACCESS_LATENCY);   

//////////////////////////////////////////////////////////////////////////
// Logic to delay certain parts of the data received from BRAM B (systolic data setup)
//////////////////////////////////////////////////////////////////////////

// Slice data into chunks and qualify it with whether it is valid or not
assign b0_data = b_data[`DWIDTH-1:0] & {`DWIDTH{b_data_valid}} & {`DWIDTH{validity_mask_b_cols[0]}};
assign b1_data = b_data[2*`DWIDTH-1:1*`DWIDTH] & {`DWIDTH{b_data_valid}} & {`DWIDTH{validity_mask_b_cols[1]}};
assign b2_data = b_data[3*`DWIDTH-1:2*`DWIDTH] & {`DWIDTH{b_data_valid}} & {`DWIDTH{validity_mask_b_cols[2]}};
assign b3_data = b_data[4*`DWIDTH-1:3*`DWIDTH] & {`DWIDTH{b_data_valid}} & {`DWIDTH{validity_mask_b_cols[3]}};
assign b4_data = b_data[5*`DWIDTH-1:4*`DWIDTH] & {`DWIDTH{b_data_valid}} & {`DWIDTH{validity_mask_b_cols[4]}};
assign b5_data = b_data[6*`DWIDTH-1:5*`DWIDTH] & {`DWIDTH{b_data_valid}} & {`DWIDTH{validity_mask_b_cols[5]}};
assign b6_data = b_data[7*`DWIDTH-1:6*`DWIDTH] & {`DWIDTH{b_data_valid}} & {`DWIDTH{validity_mask_b_cols[6]}};
assign b7_data = b_data[8*`DWIDTH-1:7*`DWIDTH] & {`DWIDTH{b_data_valid}} & {`DWIDTH{validity_mask_b_cols[7]}};
assign b8_data = b_data[9*`DWIDTH-1:8*`DWIDTH] & {`DWIDTH{b_data_valid}} & {`DWIDTH{validity_mask_b_cols[8]}};
assign b9_data = b_data[10*`DWIDTH-1:9*`DWIDTH] & {`DWIDTH{b_data_valid}} & {`DWIDTH{validity_mask_b_cols[9]}};
assign b10_data = b_data[11*`DWIDTH-1:10*`DWIDTH] & {`DWIDTH{b_data_valid}} & {`DWIDTH{validity_mask_b_cols[10]}};
assign b11_data = b_data[12*`DWIDTH-1:11*`DWIDTH] & {`DWIDTH{b_data_valid}} & {`DWIDTH{validity_mask_b_cols[11]}};
assign b12_data = b_data[13*`DWIDTH-1:12*`DWIDTH] & {`DWIDTH{b_data_valid}} & {`DWIDTH{validity_mask_b_cols[12]}};
assign b13_data = b_data[14*`DWIDTH-1:13*`DWIDTH] & {`DWIDTH{b_data_valid}} & {`DWIDTH{validity_mask_b_cols[13]}};
assign b14_data = b_data[15*`DWIDTH-1:14*`DWIDTH] & {`DWIDTH{b_data_valid}} & {`DWIDTH{validity_mask_b_cols[14]}};
assign b15_data = b_data[16*`DWIDTH-1:15*`DWIDTH] & {`DWIDTH{b_data_valid}} & {`DWIDTH{validity_mask_b_cols[15]}};

// For larger matmuls, more such delaying flops will be needed
reg [`DWIDTH-1:0] b1_data_delayed_1;
reg [`DWIDTH-1:0] b2_data_delayed_1;
reg [`DWIDTH-1:0] b2_data_delayed_2;
reg [`DWIDTH-1:0] b3_data_delayed_1;
reg [`DWIDTH-1:0] b3_data_delayed_2;
reg [`DWIDTH-1:0] b3_data_delayed_3;
reg [`DWIDTH-1:0] b4_data_delayed_1;
reg [`DWIDTH-1:0] b4_data_delayed_2;
reg [`DWIDTH-1:0] b4_data_delayed_3;
reg [`DWIDTH-1:0] b4_data_delayed_4;
reg [`DWIDTH-1:0] b5_data_delayed_1;
reg [`DWIDTH-1:0] b5_data_delayed_2;
reg [`DWIDTH-1:0] b5_data_delayed_3;
reg [`DWIDTH-1:0] b5_data_delayed_4;
reg [`DWIDTH-1:0] b5_data_delayed_5;
reg [`DWIDTH-1:0] b6_data_delayed_1;
reg [`DWIDTH-1:0] b6_data_delayed_2;
reg [`DWIDTH-1:0] b6_data_delayed_3;
reg [`DWIDTH-1:0] b6_data_delayed_4;
reg [`DWIDTH-1:0] b6_data_delayed_5;
reg [`DWIDTH-1:0] b6_data_delayed_6;
reg [`DWIDTH-1:0] b7_data_delayed_1;
reg [`DWIDTH-1:0] b7_data_delayed_2;
reg [`DWIDTH-1:0] b7_data_delayed_3;
reg [`DWIDTH-1:0] b7_data_delayed_4;
reg [`DWIDTH-1:0] b7_data_delayed_5;
reg [`DWIDTH-1:0] b7_data_delayed_6;
reg [`DWIDTH-1:0] b7_data_delayed_7;
reg [`DWIDTH-1:0] b8_data_delayed_1;
reg [`DWIDTH-1:0] b8_data_delayed_2;
reg [`DWIDTH-1:0] b8_data_delayed_3;
reg [`DWIDTH-1:0] b8_data_delayed_4;
reg [`DWIDTH-1:0] b8_data_delayed_5;
reg [`DWIDTH-1:0] b8_data_delayed_6;
reg [`DWIDTH-1:0] b8_data_delayed_7;
reg [`DWIDTH-1:0] b8_data_delayed_8;
reg [`DWIDTH-1:0] b9_data_delayed_1;
reg [`DWIDTH-1:0] b9_data_delayed_2;
reg [`DWIDTH-1:0] b9_data_delayed_3;
reg [`DWIDTH-1:0] b9_data_delayed_4;
reg [`DWIDTH-1:0] b9_data_delayed_5;
reg [`DWIDTH-1:0] b9_data_delayed_6;
reg [`DWIDTH-1:0] b9_data_delayed_7;
reg [`DWIDTH-1:0] b9_data_delayed_8;
reg [`DWIDTH-1:0] b9_data_delayed_9;
reg [`DWIDTH-1:0] b10_data_delayed_1;
reg [`DWIDTH-1:0] b10_data_delayed_2;
reg [`DWIDTH-1:0] b10_data_delayed_3;
reg [`DWIDTH-1:0] b10_data_delayed_4;
reg [`DWIDTH-1:0] b10_data_delayed_5;
reg [`DWIDTH-1:0] b10_data_delayed_6;
reg [`DWIDTH-1:0] b10_data_delayed_7;
reg [`DWIDTH-1:0] b10_data_delayed_8;
reg [`DWIDTH-1:0] b10_data_delayed_9;
reg [`DWIDTH-1:0] b10_data_delayed_10;
reg [`DWIDTH-1:0] b11_data_delayed_1;
reg [`DWIDTH-1:0] b11_data_delayed_2;
reg [`DWIDTH-1:0] b11_data_delayed_3;
reg [`DWIDTH-1:0] b11_data_delayed_4;
reg [`DWIDTH-1:0] b11_data_delayed_5;
reg [`DWIDTH-1:0] b11_data_delayed_6;
reg [`DWIDTH-1:0] b11_data_delayed_7;
reg [`DWIDTH-1:0] b11_data_delayed_8;
reg [`DWIDTH-1:0] b11_data_delayed_9;
reg [`DWIDTH-1:0] b11_data_delayed_10;
reg [`DWIDTH-1:0] b11_data_delayed_11;
reg [`DWIDTH-1:0] b12_data_delayed_1;
reg [`DWIDTH-1:0] b12_data_delayed_2;
reg [`DWIDTH-1:0] b12_data_delayed_3;
reg [`DWIDTH-1:0] b12_data_delayed_4;
reg [`DWIDTH-1:0] b12_data_delayed_5;
reg [`DWIDTH-1:0] b12_data_delayed_6;
reg [`DWIDTH-1:0] b12_data_delayed_7;
reg [`DWIDTH-1:0] b12_data_delayed_8;
reg [`DWIDTH-1:0] b12_data_delayed_9;
reg [`DWIDTH-1:0] b12_data_delayed_10;
reg [`DWIDTH-1:0] b12_data_delayed_11;
reg [`DWIDTH-1:0] b12_data_delayed_12;
reg [`DWIDTH-1:0] b13_data_delayed_1;
reg [`DWIDTH-1:0] b13_data_delayed_2;
reg [`DWIDTH-1:0] b13_data_delayed_3;
reg [`DWIDTH-1:0] b13_data_delayed_4;
reg [`DWIDTH-1:0] b13_data_delayed_5;
reg [`DWIDTH-1:0] b13_data_delayed_6;
reg [`DWIDTH-1:0] b13_data_delayed_7;
reg [`DWIDTH-1:0] b13_data_delayed_8;
reg [`DWIDTH-1:0] b13_data_delayed_9;
reg [`DWIDTH-1:0] b13_data_delayed_10;
reg [`DWIDTH-1:0] b13_data_delayed_11;
reg [`DWIDTH-1:0] b13_data_delayed_12;
reg [`DWIDTH-1:0] b13_data_delayed_13;
reg [`DWIDTH-1:0] b14_data_delayed_1;
reg [`DWIDTH-1:0] b14_data_delayed_2;
reg [`DWIDTH-1:0] b14_data_delayed_3;
reg [`DWIDTH-1:0] b14_data_delayed_4;
reg [`DWIDTH-1:0] b14_data_delayed_5;
reg [`DWIDTH-1:0] b14_data_delayed_6;
reg [`DWIDTH-1:0] b14_data_delayed_7;
reg [`DWIDTH-1:0] b14_data_delayed_8;
reg [`DWIDTH-1:0] b14_data_delayed_9;
reg [`DWIDTH-1:0] b14_data_delayed_10;
reg [`DWIDTH-1:0] b14_data_delayed_11;
reg [`DWIDTH-1:0] b14_data_delayed_12;
reg [`DWIDTH-1:0] b14_data_delayed_13;
reg [`DWIDTH-1:0] b14_data_delayed_14;
reg [`DWIDTH-1:0] b15_data_delayed_1;
reg [`DWIDTH-1:0] b15_data_delayed_2;
reg [`DWIDTH-1:0] b15_data_delayed_3;
reg [`DWIDTH-1:0] b15_data_delayed_4;
reg [`DWIDTH-1:0] b15_data_delayed_5;
reg [`DWIDTH-1:0] b15_data_delayed_6;
reg [`DWIDTH-1:0] b15_data_delayed_7;
reg [`DWIDTH-1:0] b15_data_delayed_8;
reg [`DWIDTH-1:0] b15_data_delayed_9;
reg [`DWIDTH-1:0] b15_data_delayed_10;
reg [`DWIDTH-1:0] b15_data_delayed_11;
reg [`DWIDTH-1:0] b15_data_delayed_12;
reg [`DWIDTH-1:0] b15_data_delayed_13;
reg [`DWIDTH-1:0] b15_data_delayed_14;
reg [`DWIDTH-1:0] b15_data_delayed_15;

always @(posedge clk) begin
  if (reset || ~start_mat_mul || clk_cnt==0) begin
    b1_data_delayed_1 <= 0;
    b2_data_delayed_1 <= 0;
    b2_data_delayed_2 <= 0;
    b3_data_delayed_1 <= 0;
    b3_data_delayed_2 <= 0;
    b3_data_delayed_3 <= 0;
    b4_data_delayed_1 <= 0;
    b4_data_delayed_2 <= 0;
    b4_data_delayed_3 <= 0;
    b4_data_delayed_4 <= 0;
    b5_data_delayed_1 <= 0;
    b5_data_delayed_2 <= 0;
    b5_data_delayed_3 <= 0;
    b5_data_delayed_4 <= 0;
    b5_data_delayed_5 <= 0;
    b6_data_delayed_1 <= 0;
    b6_data_delayed_2 <= 0;
    b6_data_delayed_3 <= 0;
    b6_data_delayed_4 <= 0;
    b6_data_delayed_5 <= 0;
    b6_data_delayed_6 <= 0;
    b7_data_delayed_1 <= 0;
    b7_data_delayed_2 <= 0;
    b7_data_delayed_3 <= 0;
    b7_data_delayed_4 <= 0;
    b7_data_delayed_5 <= 0;
    b7_data_delayed_6 <= 0;
    b7_data_delayed_7 <= 0;
    b8_data_delayed_1 <= 0;
    b8_data_delayed_2 <= 0;
    b8_data_delayed_3 <= 0;
    b8_data_delayed_4 <= 0;
    b8_data_delayed_5 <= 0;
    b8_data_delayed_6 <= 0;
    b8_data_delayed_7 <= 0;
    b8_data_delayed_8 <= 0;
    b9_data_delayed_1 <= 0;
    b9_data_delayed_2 <= 0;
    b9_data_delayed_3 <= 0;
    b9_data_delayed_4 <= 0;
    b9_data_delayed_5 <= 0;
    b9_data_delayed_6 <= 0;
    b9_data_delayed_7 <= 0;
    b9_data_delayed_8 <= 0;
    b9_data_delayed_9 <= 0;
    b10_data_delayed_1 <= 0;
    b10_data_delayed_2 <= 0;
    b10_data_delayed_3 <= 0;
    b10_data_delayed_4 <= 0;
    b10_data_delayed_5 <= 0;
    b10_data_delayed_6 <= 0;
    b10_data_delayed_7 <= 0;
    b10_data_delayed_8 <= 0;
    b10_data_delayed_9 <= 0;
    b10_data_delayed_10 <= 0;
    b11_data_delayed_1 <= 0;
    b11_data_delayed_2 <= 0;
    b11_data_delayed_3 <= 0;
    b11_data_delayed_4 <= 0;
    b11_data_delayed_5 <= 0;
    b11_data_delayed_6 <= 0;
    b11_data_delayed_7 <= 0;
    b11_data_delayed_8 <= 0;
    b11_data_delayed_9 <= 0;
    b11_data_delayed_10 <= 0;
    b11_data_delayed_11 <= 0;
    b12_data_delayed_1 <= 0;
    b12_data_delayed_2 <= 0;
    b12_data_delayed_3 <= 0;
    b12_data_delayed_4 <= 0;
    b12_data_delayed_5 <= 0;
    b12_data_delayed_6 <= 0;
    b12_data_delayed_7 <= 0;
    b12_data_delayed_8 <= 0;
    b12_data_delayed_9 <= 0;
    b12_data_delayed_10 <= 0;
    b12_data_delayed_11 <= 0;
    b12_data_delayed_12 <= 0;
    b13_data_delayed_1 <= 0;
    b13_data_delayed_2 <= 0;
    b13_data_delayed_3 <= 0;
    b13_data_delayed_4 <= 0;
    b13_data_delayed_5 <= 0;
    b13_data_delayed_6 <= 0;
    b13_data_delayed_7 <= 0;
    b13_data_delayed_8 <= 0;
    b13_data_delayed_9 <= 0;
    b13_data_delayed_10 <= 0;
    b13_data_delayed_11 <= 0;
    b13_data_delayed_12 <= 0;
    b13_data_delayed_13 <= 0;
    b14_data_delayed_1 <= 0;
    b14_data_delayed_2 <= 0;
    b14_data_delayed_3 <= 0;
    b14_data_delayed_4 <= 0;
    b14_data_delayed_5 <= 0;
    b14_data_delayed_6 <= 0;
    b14_data_delayed_7 <= 0;
    b14_data_delayed_8 <= 0;
    b14_data_delayed_9 <= 0;
    b14_data_delayed_10 <= 0;
    b14_data_delayed_11 <= 0;
    b14_data_delayed_12 <= 0;
    b14_data_delayed_13 <= 0;
    b14_data_delayed_14 <= 0;
    b15_data_delayed_1 <= 0;
    b15_data_delayed_2 <= 0;
    b15_data_delayed_3 <= 0;
    b15_data_delayed_4 <= 0;
    b15_data_delayed_5 <= 0;
    b15_data_delayed_6 <= 0;
    b15_data_delayed_7 <= 0;
    b15_data_delayed_8 <= 0;
    b15_data_delayed_9 <= 0;
    b15_data_delayed_10 <= 0;
    b15_data_delayed_11 <= 0;
    b15_data_delayed_12 <= 0;
    b15_data_delayed_13 <= 0;
    b15_data_delayed_14 <= 0;
    b15_data_delayed_15 <= 0;
  end
  else begin
    b1_data_delayed_1 <= b1_data;
    b2_data_delayed_1 <= b2_data;
    b2_data_delayed_2 <= b2_data_delayed_1;
    b3_data_delayed_1 <= b3_data;
    b3_data_delayed_2 <= b3_data_delayed_1;
    b3_data_delayed_3 <= b3_data_delayed_2;
    b4_data_delayed_1 <= b4_data;
    b4_data_delayed_2 <= b4_data_delayed_1;
    b4_data_delayed_3 <= b4_data_delayed_2;
    b4_data_delayed_4 <= b4_data_delayed_3;
    b5_data_delayed_1 <= b5_data;
    b5_data_delayed_2 <= b5_data_delayed_1;
    b5_data_delayed_3 <= b5_data_delayed_2;
    b5_data_delayed_4 <= b5_data_delayed_3;
    b5_data_delayed_5 <= b5_data_delayed_4;
    b6_data_delayed_1 <= b6_data;
    b6_data_delayed_2 <= b6_data_delayed_1;
    b6_data_delayed_3 <= b6_data_delayed_2;
    b6_data_delayed_4 <= b6_data_delayed_3;
    b6_data_delayed_5 <= b6_data_delayed_4;
    b6_data_delayed_6 <= b6_data_delayed_5;
    b7_data_delayed_1 <= b7_data;
    b7_data_delayed_2 <= b7_data_delayed_1;
    b7_data_delayed_3 <= b7_data_delayed_2;
    b7_data_delayed_4 <= b7_data_delayed_3;
    b7_data_delayed_5 <= b7_data_delayed_4;
    b7_data_delayed_6 <= b7_data_delayed_5;
    b7_data_delayed_7 <= b7_data_delayed_6;
    b8_data_delayed_1 <= b8_data;
    b8_data_delayed_2 <= b8_data_delayed_1;
    b8_data_delayed_3 <= b8_data_delayed_2;
    b8_data_delayed_4 <= b8_data_delayed_3;
    b8_data_delayed_5 <= b8_data_delayed_4;
    b8_data_delayed_6 <= b8_data_delayed_5;
    b8_data_delayed_7 <= b8_data_delayed_6;
    b8_data_delayed_8 <= b8_data_delayed_7;
    b9_data_delayed_1 <= b9_data;
    b9_data_delayed_2 <= b9_data_delayed_1;
    b9_data_delayed_3 <= b9_data_delayed_2;
    b9_data_delayed_4 <= b9_data_delayed_3;
    b9_data_delayed_5 <= b9_data_delayed_4;
    b9_data_delayed_6 <= b9_data_delayed_5;
    b9_data_delayed_7 <= b9_data_delayed_6;
    b9_data_delayed_8 <= b9_data_delayed_7;
    b9_data_delayed_9 <= b9_data_delayed_8;
    b10_data_delayed_1 <= b10_data;
    b10_data_delayed_2 <= b10_data_delayed_1;
    b10_data_delayed_3 <= b10_data_delayed_2;
    b10_data_delayed_4 <= b10_data_delayed_3;
    b10_data_delayed_5 <= b10_data_delayed_4;
    b10_data_delayed_6 <= b10_data_delayed_5;
    b10_data_delayed_7 <= b10_data_delayed_6;
    b10_data_delayed_8 <= b10_data_delayed_7;
    b10_data_delayed_9 <= b10_data_delayed_8;
    b10_data_delayed_10 <= b10_data_delayed_9;
    b11_data_delayed_1 <= b11_data;
    b11_data_delayed_2 <= b11_data_delayed_1;
    b11_data_delayed_3 <= b11_data_delayed_2;
    b11_data_delayed_4 <= b11_data_delayed_3;
    b11_data_delayed_5 <= b11_data_delayed_4;
    b11_data_delayed_6 <= b11_data_delayed_5;
    b11_data_delayed_7 <= b11_data_delayed_6;
    b11_data_delayed_8 <= b11_data_delayed_7;
    b11_data_delayed_9 <= b11_data_delayed_8;
    b11_data_delayed_10 <= b11_data_delayed_9;
    b11_data_delayed_11 <= b11_data_delayed_10;
    b12_data_delayed_1 <= b12_data;
    b12_data_delayed_2 <= b12_data_delayed_1;
    b12_data_delayed_3 <= b12_data_delayed_2;
    b12_data_delayed_4 <= b12_data_delayed_3;
    b12_data_delayed_5 <= b12_data_delayed_4;
    b12_data_delayed_6 <= b12_data_delayed_5;
    b12_data_delayed_7 <= b12_data_delayed_6;
    b12_data_delayed_8 <= b12_data_delayed_7;
    b12_data_delayed_9 <= b12_data_delayed_8;
    b12_data_delayed_10 <= b12_data_delayed_9;
    b12_data_delayed_11 <= b12_data_delayed_10;
    b12_data_delayed_12 <= b12_data_delayed_11;
    b13_data_delayed_1 <= b13_data;
    b13_data_delayed_2 <= b13_data_delayed_1;
    b13_data_delayed_3 <= b13_data_delayed_2;
    b13_data_delayed_4 <= b13_data_delayed_3;
    b13_data_delayed_5 <= b13_data_delayed_4;
    b13_data_delayed_6 <= b13_data_delayed_5;
    b13_data_delayed_7 <= b13_data_delayed_6;
    b13_data_delayed_8 <= b13_data_delayed_7;
    b13_data_delayed_9 <= b13_data_delayed_8;
    b13_data_delayed_10 <= b13_data_delayed_9;
    b13_data_delayed_11 <= b13_data_delayed_10;
    b13_data_delayed_12 <= b13_data_delayed_11;
    b13_data_delayed_13 <= b13_data_delayed_12;
    b14_data_delayed_1 <= b14_data;
    b14_data_delayed_2 <= b14_data_delayed_1;
    b14_data_delayed_3 <= b14_data_delayed_2;
    b14_data_delayed_4 <= b14_data_delayed_3;
    b14_data_delayed_5 <= b14_data_delayed_4;
    b14_data_delayed_6 <= b14_data_delayed_5;
    b14_data_delayed_7 <= b14_data_delayed_6;
    b14_data_delayed_8 <= b14_data_delayed_7;
    b14_data_delayed_9 <= b14_data_delayed_8;
    b14_data_delayed_10 <= b14_data_delayed_9;
    b14_data_delayed_11 <= b14_data_delayed_10;
    b14_data_delayed_12 <= b14_data_delayed_11;
    b14_data_delayed_13 <= b14_data_delayed_12;
    b14_data_delayed_14 <= b14_data_delayed_13;
    b15_data_delayed_1 <= b15_data;
    b15_data_delayed_2 <= b15_data_delayed_1;
    b15_data_delayed_3 <= b15_data_delayed_2;
    b15_data_delayed_4 <= b15_data_delayed_3;
    b15_data_delayed_5 <= b15_data_delayed_4;
    b15_data_delayed_6 <= b15_data_delayed_5;
    b15_data_delayed_7 <= b15_data_delayed_6;
    b15_data_delayed_8 <= b15_data_delayed_7;
    b15_data_delayed_9 <= b15_data_delayed_8;
    b15_data_delayed_10 <= b15_data_delayed_9;
    b15_data_delayed_11 <= b15_data_delayed_10;
    b15_data_delayed_12 <= b15_data_delayed_11;
    b15_data_delayed_13 <= b15_data_delayed_12;
    b15_data_delayed_14 <= b15_data_delayed_13;
    b15_data_delayed_15 <= b15_data_delayed_14;
  end
end
  
endmodule

//////////////////////////////////////////////////////////////////////////
// Systolically connected PEs
//////////////////////////////////////////////////////////////////////////

module systolic_pe_matrix(
    reset,
    clk,
    pe_reset,
    b_data_sel,
    a0,    a1,    a2,    a3,    a4,    a5,    a6,    a7,    a8,    a9,    a10,    a11,    a12,    a13,    a14,    a15,
    b0,    b1,    b2,    b3,    b4,    b5,    b6,    b7,    b8,    b9,    b10,    b11,    b12,    b13,    b14,    b15,
    c0,    c1,    c2,    c3,    c4,    c5,    c6,    c7,    c8,    c9,    c10,    c11,    c12,    c13,    c14,    c15,
    matrixC0_0,
    matrixC0_1,
    matrixC0_2,
    matrixC0_3,
    matrixC0_4,
    matrixC0_5,
    matrixC0_6,
    matrixC0_7,
    matrixC0_8,
    matrixC0_9,
    matrixC0_10,
    matrixC0_11,
    matrixC0_12,
    matrixC0_13,
    matrixC0_14,
    matrixC0_15,
    matrixC1_0,
    matrixC1_1,
    matrixC1_2,
    matrixC1_3,
    matrixC1_4,
    matrixC1_5,
    matrixC1_6,
    matrixC1_7,
    matrixC1_8,
    matrixC1_9,
    matrixC1_10,
    matrixC1_11,
    matrixC1_12,
    matrixC1_13,
    matrixC1_14,
    matrixC1_15,
    matrixC2_0,
    matrixC2_1,
    matrixC2_2,
    matrixC2_3,
    matrixC2_4,
    matrixC2_5,
    matrixC2_6,
    matrixC2_7,
    matrixC2_8,
    matrixC2_9,
    matrixC2_10,
    matrixC2_11,
    matrixC2_12,
    matrixC2_13,
    matrixC2_14,
    matrixC2_15,
    matrixC3_0,
    matrixC3_1,
    matrixC3_2,
    matrixC3_3,
    matrixC3_4,
    matrixC3_5,
    matrixC3_6,
    matrixC3_7,
    matrixC3_8,
    matrixC3_9,
    matrixC3_10,
    matrixC3_11,
    matrixC3_12,
    matrixC3_13,
    matrixC3_14,
    matrixC3_15,
    matrixC4_0,
    matrixC4_1,
    matrixC4_2,
    matrixC4_3,
    matrixC4_4,
    matrixC4_5,
    matrixC4_6,
    matrixC4_7,
    matrixC4_8,
    matrixC4_9,
    matrixC4_10,
    matrixC4_11,
    matrixC4_12,
    matrixC4_13,
    matrixC4_14,
    matrixC4_15,
    matrixC5_0,
    matrixC5_1,
    matrixC5_2,
    matrixC5_3,
    matrixC5_4,
    matrixC5_5,
    matrixC5_6,
    matrixC5_7,
    matrixC5_8,
    matrixC5_9,
    matrixC5_10,
    matrixC5_11,
    matrixC5_12,
    matrixC5_13,
    matrixC5_14,
    matrixC5_15,
    matrixC6_0,
    matrixC6_1,
    matrixC6_2,
    matrixC6_3,
    matrixC6_4,
    matrixC6_5,
    matrixC6_6,
    matrixC6_7,
    matrixC6_8,
    matrixC6_9,
    matrixC6_10,
    matrixC6_11,
    matrixC6_12,
    matrixC6_13,
    matrixC6_14,
    matrixC6_15,
    matrixC7_0,
    matrixC7_1,
    matrixC7_2,
    matrixC7_3,
    matrixC7_4,
    matrixC7_5,
    matrixC7_6,
    matrixC7_7,
    matrixC7_8,
    matrixC7_9,
    matrixC7_10,
    matrixC7_11,
    matrixC7_12,
    matrixC7_13,
    matrixC7_14,
    matrixC7_15,
    matrixC8_0,
    matrixC8_1,
    matrixC8_2,
    matrixC8_3,
    matrixC8_4,
    matrixC8_5,
    matrixC8_6,
    matrixC8_7,
    matrixC8_8,
    matrixC8_9,
    matrixC8_10,
    matrixC8_11,
    matrixC8_12,
    matrixC8_13,
    matrixC8_14,
    matrixC8_15,
    matrixC9_0,
    matrixC9_1,
    matrixC9_2,
    matrixC9_3,
    matrixC9_4,
    matrixC9_5,
    matrixC9_6,
    matrixC9_7,
    matrixC9_8,
    matrixC9_9,
    matrixC9_10,
    matrixC9_11,
    matrixC9_12,
    matrixC9_13,
    matrixC9_14,
    matrixC9_15,
    matrixC10_0,
    matrixC10_1,
    matrixC10_2,
    matrixC10_3,
    matrixC10_4,
    matrixC10_5,
    matrixC10_6,
    matrixC10_7,
    matrixC10_8,
    matrixC10_9,
    matrixC10_10,
    matrixC10_11,
    matrixC10_12,
    matrixC10_13,
    matrixC10_14,
    matrixC10_15,
    matrixC11_0,
    matrixC11_1,
    matrixC11_2,
    matrixC11_3,
    matrixC11_4,
    matrixC11_5,
    matrixC11_6,
    matrixC11_7,
    matrixC11_8,
    matrixC11_9,
    matrixC11_10,
    matrixC11_11,
    matrixC11_12,
    matrixC11_13,
    matrixC11_14,
    matrixC11_15,
    matrixC12_0,
    matrixC12_1,
    matrixC12_2,
    matrixC12_3,
    matrixC12_4,
    matrixC12_5,
    matrixC12_6,
    matrixC12_7,
    matrixC12_8,
    matrixC12_9,
    matrixC12_10,
    matrixC12_11,
    matrixC12_12,
    matrixC12_13,
    matrixC12_14,
    matrixC12_15,
    matrixC13_0,
    matrixC13_1,
    matrixC13_2,
    matrixC13_3,
    matrixC13_4,
    matrixC13_5,
    matrixC13_6,
    matrixC13_7,
    matrixC13_8,
    matrixC13_9,
    matrixC13_10,
    matrixC13_11,
    matrixC13_12,
    matrixC13_13,
    matrixC13_14,
    matrixC13_15,
    matrixC14_0,
    matrixC14_1,
    matrixC14_2,
    matrixC14_3,
    matrixC14_4,
    matrixC14_5,
    matrixC14_6,
    matrixC14_7,
    matrixC14_8,
    matrixC14_9,
    matrixC14_10,
    matrixC14_11,
    matrixC14_12,
    matrixC14_13,
    matrixC14_14,
    matrixC14_15,
    matrixC15_0,
    matrixC15_1,
    matrixC15_2,
    matrixC15_3,
    matrixC15_4,
    matrixC15_5,
    matrixC15_6,
    matrixC15_7,
    matrixC15_8,
    matrixC15_9,
    matrixC15_10,
    matrixC15_11,
    matrixC15_12,
    matrixC15_13,
    matrixC15_14,
    matrixC15_15,
    a_data_out,
    b_data_out,
    b_data_valid_ping,
    b_data_valid_pong
);

input clk;
input reset;
input pe_reset;
input b_data_sel;
input b_data_valid_ping;
input b_data_valid_pong;
input [`DWIDTH-1:0] a0;
input [`DWIDTH-1:0] a1;
input [`DWIDTH-1:0] a2;
input [`DWIDTH-1:0] a3;
input [`DWIDTH-1:0] a4;
input [`DWIDTH-1:0] a5;
input [`DWIDTH-1:0] a6;
input [`DWIDTH-1:0] a7;
input [`DWIDTH-1:0] a8;
input [`DWIDTH-1:0] a9;
input [`DWIDTH-1:0] a10;
input [`DWIDTH-1:0] a11;
input [`DWIDTH-1:0] a12;
input [`DWIDTH-1:0] a13;
input [`DWIDTH-1:0] a14;
input [`DWIDTH-1:0] a15;
input [`DWIDTH-1:0] b0;
input [`DWIDTH-1:0] b1;
input [`DWIDTH-1:0] b2;
input [`DWIDTH-1:0] b3;
input [`DWIDTH-1:0] b4;
input [`DWIDTH-1:0] b5;
input [`DWIDTH-1:0] b6;
input [`DWIDTH-1:0] b7;
input [`DWIDTH-1:0] b8;
input [`DWIDTH-1:0] b9;
input [`DWIDTH-1:0] b10;
input [`DWIDTH-1:0] b11;
input [`DWIDTH-1:0] b12;
input [`DWIDTH-1:0] b13;
input [`DWIDTH-1:0] b14;
input [`DWIDTH-1:0] b15;
input [`DWIDTH-1:0] c0;
input [`DWIDTH-1:0] c1;
input [`DWIDTH-1:0] c2;
input [`DWIDTH-1:0] c3;
input [`DWIDTH-1:0] c4;
input [`DWIDTH-1:0] c5;
input [`DWIDTH-1:0] c6;
input [`DWIDTH-1:0] c7;
input [`DWIDTH-1:0] c8;
input [`DWIDTH-1:0] c9;
input [`DWIDTH-1:0] c10;
input [`DWIDTH-1:0] c11;
input [`DWIDTH-1:0] c12;
input [`DWIDTH-1:0] c13;
input [`DWIDTH-1:0] c14;
input [`DWIDTH-1:0] c15;
output [`DWIDTH-1:0] matrixC0_0;
output [`DWIDTH-1:0] matrixC0_1;
output [`DWIDTH-1:0] matrixC0_2;
output [`DWIDTH-1:0] matrixC0_3;
output [`DWIDTH-1:0] matrixC0_4;
output [`DWIDTH-1:0] matrixC0_5;
output [`DWIDTH-1:0] matrixC0_6;
output [`DWIDTH-1:0] matrixC0_7;
output [`DWIDTH-1:0] matrixC0_8;
output [`DWIDTH-1:0] matrixC0_9;
output [`DWIDTH-1:0] matrixC0_10;
output [`DWIDTH-1:0] matrixC0_11;
output [`DWIDTH-1:0] matrixC0_12;
output [`DWIDTH-1:0] matrixC0_13;
output [`DWIDTH-1:0] matrixC0_14;
output [`DWIDTH-1:0] matrixC0_15;
output [`DWIDTH-1:0] matrixC1_0;
output [`DWIDTH-1:0] matrixC1_1;
output [`DWIDTH-1:0] matrixC1_2;
output [`DWIDTH-1:0] matrixC1_3;
output [`DWIDTH-1:0] matrixC1_4;
output [`DWIDTH-1:0] matrixC1_5;
output [`DWIDTH-1:0] matrixC1_6;
output [`DWIDTH-1:0] matrixC1_7;
output [`DWIDTH-1:0] matrixC1_8;
output [`DWIDTH-1:0] matrixC1_9;
output [`DWIDTH-1:0] matrixC1_10;
output [`DWIDTH-1:0] matrixC1_11;
output [`DWIDTH-1:0] matrixC1_12;
output [`DWIDTH-1:0] matrixC1_13;
output [`DWIDTH-1:0] matrixC1_14;
output [`DWIDTH-1:0] matrixC1_15;
output [`DWIDTH-1:0] matrixC2_0;
output [`DWIDTH-1:0] matrixC2_1;
output [`DWIDTH-1:0] matrixC2_2;
output [`DWIDTH-1:0] matrixC2_3;
output [`DWIDTH-1:0] matrixC2_4;
output [`DWIDTH-1:0] matrixC2_5;
output [`DWIDTH-1:0] matrixC2_6;
output [`DWIDTH-1:0] matrixC2_7;
output [`DWIDTH-1:0] matrixC2_8;
output [`DWIDTH-1:0] matrixC2_9;
output [`DWIDTH-1:0] matrixC2_10;
output [`DWIDTH-1:0] matrixC2_11;
output [`DWIDTH-1:0] matrixC2_12;
output [`DWIDTH-1:0] matrixC2_13;
output [`DWIDTH-1:0] matrixC2_14;
output [`DWIDTH-1:0] matrixC2_15;
output [`DWIDTH-1:0] matrixC3_0;
output [`DWIDTH-1:0] matrixC3_1;
output [`DWIDTH-1:0] matrixC3_2;
output [`DWIDTH-1:0] matrixC3_3;
output [`DWIDTH-1:0] matrixC3_4;
output [`DWIDTH-1:0] matrixC3_5;
output [`DWIDTH-1:0] matrixC3_6;
output [`DWIDTH-1:0] matrixC3_7;
output [`DWIDTH-1:0] matrixC3_8;
output [`DWIDTH-1:0] matrixC3_9;
output [`DWIDTH-1:0] matrixC3_10;
output [`DWIDTH-1:0] matrixC3_11;
output [`DWIDTH-1:0] matrixC3_12;
output [`DWIDTH-1:0] matrixC3_13;
output [`DWIDTH-1:0] matrixC3_14;
output [`DWIDTH-1:0] matrixC3_15;
output [`DWIDTH-1:0] matrixC4_0;
output [`DWIDTH-1:0] matrixC4_1;
output [`DWIDTH-1:0] matrixC4_2;
output [`DWIDTH-1:0] matrixC4_3;
output [`DWIDTH-1:0] matrixC4_4;
output [`DWIDTH-1:0] matrixC4_5;
output [`DWIDTH-1:0] matrixC4_6;
output [`DWIDTH-1:0] matrixC4_7;
output [`DWIDTH-1:0] matrixC4_8;
output [`DWIDTH-1:0] matrixC4_9;
output [`DWIDTH-1:0] matrixC4_10;
output [`DWIDTH-1:0] matrixC4_11;
output [`DWIDTH-1:0] matrixC4_12;
output [`DWIDTH-1:0] matrixC4_13;
output [`DWIDTH-1:0] matrixC4_14;
output [`DWIDTH-1:0] matrixC4_15;
output [`DWIDTH-1:0] matrixC5_0;
output [`DWIDTH-1:0] matrixC5_1;
output [`DWIDTH-1:0] matrixC5_2;
output [`DWIDTH-1:0] matrixC5_3;
output [`DWIDTH-1:0] matrixC5_4;
output [`DWIDTH-1:0] matrixC5_5;
output [`DWIDTH-1:0] matrixC5_6;
output [`DWIDTH-1:0] matrixC5_7;
output [`DWIDTH-1:0] matrixC5_8;
output [`DWIDTH-1:0] matrixC5_9;
output [`DWIDTH-1:0] matrixC5_10;
output [`DWIDTH-1:0] matrixC5_11;
output [`DWIDTH-1:0] matrixC5_12;
output [`DWIDTH-1:0] matrixC5_13;
output [`DWIDTH-1:0] matrixC5_14;
output [`DWIDTH-1:0] matrixC5_15;
output [`DWIDTH-1:0] matrixC6_0;
output [`DWIDTH-1:0] matrixC6_1;
output [`DWIDTH-1:0] matrixC6_2;
output [`DWIDTH-1:0] matrixC6_3;
output [`DWIDTH-1:0] matrixC6_4;
output [`DWIDTH-1:0] matrixC6_5;
output [`DWIDTH-1:0] matrixC6_6;
output [`DWIDTH-1:0] matrixC6_7;
output [`DWIDTH-1:0] matrixC6_8;
output [`DWIDTH-1:0] matrixC6_9;
output [`DWIDTH-1:0] matrixC6_10;
output [`DWIDTH-1:0] matrixC6_11;
output [`DWIDTH-1:0] matrixC6_12;
output [`DWIDTH-1:0] matrixC6_13;
output [`DWIDTH-1:0] matrixC6_14;
output [`DWIDTH-1:0] matrixC6_15;
output [`DWIDTH-1:0] matrixC7_0;
output [`DWIDTH-1:0] matrixC7_1;
output [`DWIDTH-1:0] matrixC7_2;
output [`DWIDTH-1:0] matrixC7_3;
output [`DWIDTH-1:0] matrixC7_4;
output [`DWIDTH-1:0] matrixC7_5;
output [`DWIDTH-1:0] matrixC7_6;
output [`DWIDTH-1:0] matrixC7_7;
output [`DWIDTH-1:0] matrixC7_8;
output [`DWIDTH-1:0] matrixC7_9;
output [`DWIDTH-1:0] matrixC7_10;
output [`DWIDTH-1:0] matrixC7_11;
output [`DWIDTH-1:0] matrixC7_12;
output [`DWIDTH-1:0] matrixC7_13;
output [`DWIDTH-1:0] matrixC7_14;
output [`DWIDTH-1:0] matrixC7_15;
output [`DWIDTH-1:0] matrixC8_0;
output [`DWIDTH-1:0] matrixC8_1;
output [`DWIDTH-1:0] matrixC8_2;
output [`DWIDTH-1:0] matrixC8_3;
output [`DWIDTH-1:0] matrixC8_4;
output [`DWIDTH-1:0] matrixC8_5;
output [`DWIDTH-1:0] matrixC8_6;
output [`DWIDTH-1:0] matrixC8_7;
output [`DWIDTH-1:0] matrixC8_8;
output [`DWIDTH-1:0] matrixC8_9;
output [`DWIDTH-1:0] matrixC8_10;
output [`DWIDTH-1:0] matrixC8_11;
output [`DWIDTH-1:0] matrixC8_12;
output [`DWIDTH-1:0] matrixC8_13;
output [`DWIDTH-1:0] matrixC8_14;
output [`DWIDTH-1:0] matrixC8_15;
output [`DWIDTH-1:0] matrixC9_0;
output [`DWIDTH-1:0] matrixC9_1;
output [`DWIDTH-1:0] matrixC9_2;
output [`DWIDTH-1:0] matrixC9_3;
output [`DWIDTH-1:0] matrixC9_4;
output [`DWIDTH-1:0] matrixC9_5;
output [`DWIDTH-1:0] matrixC9_6;
output [`DWIDTH-1:0] matrixC9_7;
output [`DWIDTH-1:0] matrixC9_8;
output [`DWIDTH-1:0] matrixC9_9;
output [`DWIDTH-1:0] matrixC9_10;
output [`DWIDTH-1:0] matrixC9_11;
output [`DWIDTH-1:0] matrixC9_12;
output [`DWIDTH-1:0] matrixC9_13;
output [`DWIDTH-1:0] matrixC9_14;
output [`DWIDTH-1:0] matrixC9_15;
output [`DWIDTH-1:0] matrixC10_0;
output [`DWIDTH-1:0] matrixC10_1;
output [`DWIDTH-1:0] matrixC10_2;
output [`DWIDTH-1:0] matrixC10_3;
output [`DWIDTH-1:0] matrixC10_4;
output [`DWIDTH-1:0] matrixC10_5;
output [`DWIDTH-1:0] matrixC10_6;
output [`DWIDTH-1:0] matrixC10_7;
output [`DWIDTH-1:0] matrixC10_8;
output [`DWIDTH-1:0] matrixC10_9;
output [`DWIDTH-1:0] matrixC10_10;
output [`DWIDTH-1:0] matrixC10_11;
output [`DWIDTH-1:0] matrixC10_12;
output [`DWIDTH-1:0] matrixC10_13;
output [`DWIDTH-1:0] matrixC10_14;
output [`DWIDTH-1:0] matrixC10_15;
output [`DWIDTH-1:0] matrixC11_0;
output [`DWIDTH-1:0] matrixC11_1;
output [`DWIDTH-1:0] matrixC11_2;
output [`DWIDTH-1:0] matrixC11_3;
output [`DWIDTH-1:0] matrixC11_4;
output [`DWIDTH-1:0] matrixC11_5;
output [`DWIDTH-1:0] matrixC11_6;
output [`DWIDTH-1:0] matrixC11_7;
output [`DWIDTH-1:0] matrixC11_8;
output [`DWIDTH-1:0] matrixC11_9;
output [`DWIDTH-1:0] matrixC11_10;
output [`DWIDTH-1:0] matrixC11_11;
output [`DWIDTH-1:0] matrixC11_12;
output [`DWIDTH-1:0] matrixC11_13;
output [`DWIDTH-1:0] matrixC11_14;
output [`DWIDTH-1:0] matrixC11_15;
output [`DWIDTH-1:0] matrixC12_0;
output [`DWIDTH-1:0] matrixC12_1;
output [`DWIDTH-1:0] matrixC12_2;
output [`DWIDTH-1:0] matrixC12_3;
output [`DWIDTH-1:0] matrixC12_4;
output [`DWIDTH-1:0] matrixC12_5;
output [`DWIDTH-1:0] matrixC12_6;
output [`DWIDTH-1:0] matrixC12_7;
output [`DWIDTH-1:0] matrixC12_8;
output [`DWIDTH-1:0] matrixC12_9;
output [`DWIDTH-1:0] matrixC12_10;
output [`DWIDTH-1:0] matrixC12_11;
output [`DWIDTH-1:0] matrixC12_12;
output [`DWIDTH-1:0] matrixC12_13;
output [`DWIDTH-1:0] matrixC12_14;
output [`DWIDTH-1:0] matrixC12_15;
output [`DWIDTH-1:0] matrixC13_0;
output [`DWIDTH-1:0] matrixC13_1;
output [`DWIDTH-1:0] matrixC13_2;
output [`DWIDTH-1:0] matrixC13_3;
output [`DWIDTH-1:0] matrixC13_4;
output [`DWIDTH-1:0] matrixC13_5;
output [`DWIDTH-1:0] matrixC13_6;
output [`DWIDTH-1:0] matrixC13_7;
output [`DWIDTH-1:0] matrixC13_8;
output [`DWIDTH-1:0] matrixC13_9;
output [`DWIDTH-1:0] matrixC13_10;
output [`DWIDTH-1:0] matrixC13_11;
output [`DWIDTH-1:0] matrixC13_12;
output [`DWIDTH-1:0] matrixC13_13;
output [`DWIDTH-1:0] matrixC13_14;
output [`DWIDTH-1:0] matrixC13_15;
output [`DWIDTH-1:0] matrixC14_0;
output [`DWIDTH-1:0] matrixC14_1;
output [`DWIDTH-1:0] matrixC14_2;
output [`DWIDTH-1:0] matrixC14_3;
output [`DWIDTH-1:0] matrixC14_4;
output [`DWIDTH-1:0] matrixC14_5;
output [`DWIDTH-1:0] matrixC14_6;
output [`DWIDTH-1:0] matrixC14_7;
output [`DWIDTH-1:0] matrixC14_8;
output [`DWIDTH-1:0] matrixC14_9;
output [`DWIDTH-1:0] matrixC14_10;
output [`DWIDTH-1:0] matrixC14_11;
output [`DWIDTH-1:0] matrixC14_12;
output [`DWIDTH-1:0] matrixC14_13;
output [`DWIDTH-1:0] matrixC14_14;
output [`DWIDTH-1:0] matrixC14_15;
output [`DWIDTH-1:0] matrixC15_0;
output [`DWIDTH-1:0] matrixC15_1;
output [`DWIDTH-1:0] matrixC15_2;
output [`DWIDTH-1:0] matrixC15_3;
output [`DWIDTH-1:0] matrixC15_4;
output [`DWIDTH-1:0] matrixC15_5;
output [`DWIDTH-1:0] matrixC15_6;
output [`DWIDTH-1:0] matrixC15_7;
output [`DWIDTH-1:0] matrixC15_8;
output [`DWIDTH-1:0] matrixC15_9;
output [`DWIDTH-1:0] matrixC15_10;
output [`DWIDTH-1:0] matrixC15_11;
output [`DWIDTH-1:0] matrixC15_12;
output [`DWIDTH-1:0] matrixC15_13;
output [`DWIDTH-1:0] matrixC15_14;
output [`DWIDTH-1:0] matrixC15_15;
output [`MAT_MUL_SIZE*`DWIDTH-1:0] a_data_out;
output [`MAT_MUL_SIZE*`DWIDTH-1:0] b_data_out;
  

wire [`DWIDTH-1:0] a0_0to0_1, a0_1to0_2, a0_2to0_3, a0_3to0_4, a0_4to0_5, a0_5to0_6, a0_6to0_7, a0_7to0_8, a0_8to0_9, a0_9to0_10, a0_10to0_11, a0_11to0_12, a0_12to0_13, a0_13to0_14, a0_14to0_15, a0_15to0_16;
wire [`DWIDTH-1:0] a1_0to1_1, a1_1to1_2, a1_2to1_3, a1_3to1_4, a1_4to1_5, a1_5to1_6, a1_6to1_7, a1_7to1_8, a1_8to1_9, a1_9to1_10, a1_10to1_11, a1_11to1_12, a1_12to1_13, a1_13to1_14, a1_14to1_15, a1_15to1_16;
wire [`DWIDTH-1:0] a2_0to2_1, a2_1to2_2, a2_2to2_3, a2_3to2_4, a2_4to2_5, a2_5to2_6, a2_6to2_7, a2_7to2_8, a2_8to2_9, a2_9to2_10, a2_10to2_11, a2_11to2_12, a2_12to2_13, a2_13to2_14, a2_14to2_15, a2_15to2_16;
wire [`DWIDTH-1:0] a3_0to3_1, a3_1to3_2, a3_2to3_3, a3_3to3_4, a3_4to3_5, a3_5to3_6, a3_6to3_7, a3_7to3_8, a3_8to3_9, a3_9to3_10, a3_10to3_11, a3_11to3_12, a3_12to3_13, a3_13to3_14, a3_14to3_15, a3_15to3_16;
wire [`DWIDTH-1:0] a4_0to4_1, a4_1to4_2, a4_2to4_3, a4_3to4_4, a4_4to4_5, a4_5to4_6, a4_6to4_7, a4_7to4_8, a4_8to4_9, a4_9to4_10, a4_10to4_11, a4_11to4_12, a4_12to4_13, a4_13to4_14, a4_14to4_15, a4_15to4_16;
wire [`DWIDTH-1:0] a5_0to5_1, a5_1to5_2, a5_2to5_3, a5_3to5_4, a5_4to5_5, a5_5to5_6, a5_6to5_7, a5_7to5_8, a5_8to5_9, a5_9to5_10, a5_10to5_11, a5_11to5_12, a5_12to5_13, a5_13to5_14, a5_14to5_15, a5_15to5_16;
wire [`DWIDTH-1:0] a6_0to6_1, a6_1to6_2, a6_2to6_3, a6_3to6_4, a6_4to6_5, a6_5to6_6, a6_6to6_7, a6_7to6_8, a6_8to6_9, a6_9to6_10, a6_10to6_11, a6_11to6_12, a6_12to6_13, a6_13to6_14, a6_14to6_15, a6_15to6_16;
wire [`DWIDTH-1:0] a7_0to7_1, a7_1to7_2, a7_2to7_3, a7_3to7_4, a7_4to7_5, a7_5to7_6, a7_6to7_7, a7_7to7_8, a7_8to7_9, a7_9to7_10, a7_10to7_11, a7_11to7_12, a7_12to7_13, a7_13to7_14, a7_14to7_15, a7_15to7_16;
wire [`DWIDTH-1:0] a8_0to8_1, a8_1to8_2, a8_2to8_3, a8_3to8_4, a8_4to8_5, a8_5to8_6, a8_6to8_7, a8_7to8_8, a8_8to8_9, a8_9to8_10, a8_10to8_11, a8_11to8_12, a8_12to8_13, a8_13to8_14, a8_14to8_15, a8_15to8_16;
wire [`DWIDTH-1:0] a9_0to9_1, a9_1to9_2, a9_2to9_3, a9_3to9_4, a9_4to9_5, a9_5to9_6, a9_6to9_7, a9_7to9_8, a9_8to9_9, a9_9to9_10, a9_10to9_11, a9_11to9_12, a9_12to9_13, a9_13to9_14, a9_14to9_15, a9_15to9_16;
wire [`DWIDTH-1:0] a10_0to10_1, a10_1to10_2, a10_2to10_3, a10_3to10_4, a10_4to10_5, a10_5to10_6, a10_6to10_7, a10_7to10_8, a10_8to10_9, a10_9to10_10, a10_10to10_11, a10_11to10_12, a10_12to10_13, a10_13to10_14, a10_14to10_15, a10_15to10_16;
wire [`DWIDTH-1:0] a11_0to11_1, a11_1to11_2, a11_2to11_3, a11_3to11_4, a11_4to11_5, a11_5to11_6, a11_6to11_7, a11_7to11_8, a11_8to11_9, a11_9to11_10, a11_10to11_11, a11_11to11_12, a11_12to11_13, a11_13to11_14, a11_14to11_15, a11_15to11_16;
wire [`DWIDTH-1:0] a12_0to12_1, a12_1to12_2, a12_2to12_3, a12_3to12_4, a12_4to12_5, a12_5to12_6, a12_6to12_7, a12_7to12_8, a12_8to12_9, a12_9to12_10, a12_10to12_11, a12_11to12_12, a12_12to12_13, a12_13to12_14, a12_14to12_15, a12_15to12_16;
wire [`DWIDTH-1:0] a13_0to13_1, a13_1to13_2, a13_2to13_3, a13_3to13_4, a13_4to13_5, a13_5to13_6, a13_6to13_7, a13_7to13_8, a13_8to13_9, a13_9to13_10, a13_10to13_11, a13_11to13_12, a13_12to13_13, a13_13to13_14, a13_14to13_15, a13_15to13_16;
wire [`DWIDTH-1:0] a14_0to14_1, a14_1to14_2, a14_2to14_3, a14_3to14_4, a14_4to14_5, a14_5to14_6, a14_6to14_7, a14_7to14_8, a14_8to14_9, a14_9to14_10, a14_10to14_11, a14_11to14_12, a14_12to14_13, a14_13to14_14, a14_14to14_15, a14_15to14_16;
wire [`DWIDTH-1:0] a15_0to15_1, a15_1to15_2, a15_2to15_3, a15_3to15_4, a15_4to15_5, a15_5to15_6, a15_6to15_7, a15_7to15_8, a15_8to15_9, a15_9to15_10, a15_10to15_11, a15_11to15_12, a15_12to15_13, a15_13to15_14, a15_14to15_15, a15_15to15_16;

wire [`DWIDTH-1:0] b0_0to1_0, b1_0to2_0, b2_0to3_0, b3_0to4_0, b4_0to5_0, b5_0to6_0, b6_0to7_0, b7_0to8_0, b8_0to9_0, b9_0to10_0, b10_0to11_0, b11_0to12_0, b12_0to13_0, b13_0to14_0, b14_0to15_0, b15_0to16_0;
wire [`DWIDTH-1:0] b0_1to1_1, b1_1to2_1, b2_1to3_1, b3_1to4_1, b4_1to5_1, b5_1to6_1, b6_1to7_1, b7_1to8_1, b8_1to9_1, b9_1to10_1, b10_1to11_1, b11_1to12_1, b12_1to13_1, b13_1to14_1, b14_1to15_1, b15_1to16_1;
wire [`DWIDTH-1:0] b0_2to1_2, b1_2to2_2, b2_2to3_2, b3_2to4_2, b4_2to5_2, b5_2to6_2, b6_2to7_2, b7_2to8_2, b8_2to9_2, b9_2to10_2, b10_2to11_2, b11_2to12_2, b12_2to13_2, b13_2to14_2, b14_2to15_2, b15_2to16_2;
wire [`DWIDTH-1:0] b0_3to1_3, b1_3to2_3, b2_3to3_3, b3_3to4_3, b4_3to5_3, b5_3to6_3, b6_3to7_3, b7_3to8_3, b8_3to9_3, b9_3to10_3, b10_3to11_3, b11_3to12_3, b12_3to13_3, b13_3to14_3, b14_3to15_3, b15_3to16_3;
wire [`DWIDTH-1:0] b0_4to1_4, b1_4to2_4, b2_4to3_4, b3_4to4_4, b4_4to5_4, b5_4to6_4, b6_4to7_4, b7_4to8_4, b8_4to9_4, b9_4to10_4, b10_4to11_4, b11_4to12_4, b12_4to13_4, b13_4to14_4, b14_4to15_4, b15_4to16_4;
wire [`DWIDTH-1:0] b0_5to1_5, b1_5to2_5, b2_5to3_5, b3_5to4_5, b4_5to5_5, b5_5to6_5, b6_5to7_5, b7_5to8_5, b8_5to9_5, b9_5to10_5, b10_5to11_5, b11_5to12_5, b12_5to13_5, b13_5to14_5, b14_5to15_5, b15_5to16_5;
wire [`DWIDTH-1:0] b0_6to1_6, b1_6to2_6, b2_6to3_6, b3_6to4_6, b4_6to5_6, b5_6to6_6, b6_6to7_6, b7_6to8_6, b8_6to9_6, b9_6to10_6, b10_6to11_6, b11_6to12_6, b12_6to13_6, b13_6to14_6, b14_6to15_6, b15_6to16_6;
wire [`DWIDTH-1:0] b0_7to1_7, b1_7to2_7, b2_7to3_7, b3_7to4_7, b4_7to5_7, b5_7to6_7, b6_7to7_7, b7_7to8_7, b8_7to9_7, b9_7to10_7, b10_7to11_7, b11_7to12_7, b12_7to13_7, b13_7to14_7, b14_7to15_7, b15_7to16_7;
wire [`DWIDTH-1:0] b0_8to1_8, b1_8to2_8, b2_8to3_8, b3_8to4_8, b4_8to5_8, b5_8to6_8, b6_8to7_8, b7_8to8_8, b8_8to9_8, b9_8to10_8, b10_8to11_8, b11_8to12_8, b12_8to13_8, b13_8to14_8, b14_8to15_8, b15_8to16_8;
wire [`DWIDTH-1:0] b0_9to1_9, b1_9to2_9, b2_9to3_9, b3_9to4_9, b4_9to5_9, b5_9to6_9, b6_9to7_9, b7_9to8_9, b8_9to9_9, b9_9to10_9, b10_9to11_9, b11_9to12_9, b12_9to13_9, b13_9to14_9, b14_9to15_9, b15_9to16_9;
wire [`DWIDTH-1:0] b0_10to1_10, b1_10to2_10, b2_10to3_10, b3_10to4_10, b4_10to5_10, b5_10to6_10, b6_10to7_10, b7_10to8_10, b8_10to9_10, b9_10to10_10, b10_10to11_10, b11_10to12_10, b12_10to13_10, b13_10to14_10, b14_10to15_10, b15_10to16_10;
wire [`DWIDTH-1:0] b0_11to1_11, b1_11to2_11, b2_11to3_11, b3_11to4_11, b4_11to5_11, b5_11to6_11, b6_11to7_11, b7_11to8_11, b8_11to9_11, b9_11to10_11, b10_11to11_11, b11_11to12_11, b12_11to13_11, b13_11to14_11, b14_11to15_11, b15_11to16_11;
wire [`DWIDTH-1:0] b0_12to1_12, b1_12to2_12, b2_12to3_12, b3_12to4_12, b4_12to5_12, b5_12to6_12, b6_12to7_12, b7_12to8_12, b8_12to9_12, b9_12to10_12, b10_12to11_12, b11_12to12_12, b12_12to13_12, b13_12to14_12, b14_12to15_12, b15_12to16_12;
wire [`DWIDTH-1:0] b0_13to1_13, b1_13to2_13, b2_13to3_13, b3_13to4_13, b4_13to5_13, b5_13to6_13, b6_13to7_13, b7_13to8_13, b8_13to9_13, b9_13to10_13, b10_13to11_13, b11_13to12_13, b12_13to13_13, b13_13to14_13, b14_13to15_13, b15_13to16_13;
wire [`DWIDTH-1:0] b0_14to1_14, b1_14to2_14, b2_14to3_14, b3_14to4_14, b4_14to5_14, b5_14to6_14, b6_14to7_14, b7_14to8_14, b8_14to9_14, b9_14to10_14, b10_14to11_14, b11_14to12_14, b12_14to13_14, b13_14to14_14, b14_14to15_14, b15_14to16_14;
wire [`DWIDTH-1:0] b0_15to1_15, b1_15to2_15, b2_15to3_15, b3_15to4_15, b4_15to5_15, b5_15to6_15, b6_15to7_15, b7_15to8_15, b8_15to9_15, b9_15to10_15, b10_15to11_15, b11_15to12_15, b12_15to13_15, b13_15to14_15, b14_15to15_15, b15_15to16_15;

wire [`DWIDTH-1:0] b0_0to1_0_ping, b1_0to2_0_ping, b2_0to3_0_ping, b3_0to4_0_ping, b4_0to5_0_ping, b5_0to6_0_ping, b6_0to7_0_ping, b7_0to8_0_ping, b8_0to9_0_ping, b9_0to10_0_ping, b10_0to11_0_ping, b11_0to12_0_ping, b12_0to13_0_ping, b13_0to14_0_ping, b14_0to15_0_ping, b15_0to16_0_ping;
wire [`DWIDTH-1:0] b0_1to1_1_ping, b1_1to2_1_ping, b2_1to3_1_ping, b3_1to4_1_ping, b4_1to5_1_ping, b5_1to6_1_ping, b6_1to7_1_ping, b7_1to8_1_ping, b8_1to9_1_ping, b9_1to10_1_ping, b10_1to11_1_ping, b11_1to12_1_ping, b12_1to13_1_ping, b13_1to14_1_ping, b14_1to15_1_ping, b15_1to16_1_ping;
wire [`DWIDTH-1:0] b0_2to1_2_ping, b1_2to2_2_ping, b2_2to3_2_ping, b3_2to4_2_ping, b4_2to5_2_ping, b5_2to6_2_ping, b6_2to7_2_ping, b7_2to8_2_ping, b8_2to9_2_ping, b9_2to10_2_ping, b10_2to11_2_ping, b11_2to12_2_ping, b12_2to13_2_ping, b13_2to14_2_ping, b14_2to15_2_ping, b15_2to16_2_ping;
wire [`DWIDTH-1:0] b0_3to1_3_ping, b1_3to2_3_ping, b2_3to3_3_ping, b3_3to4_3_ping, b4_3to5_3_ping, b5_3to6_3_ping, b6_3to7_3_ping, b7_3to8_3_ping, b8_3to9_3_ping, b9_3to10_3_ping, b10_3to11_3_ping, b11_3to12_3_ping, b12_3to13_3_ping, b13_3to14_3_ping, b14_3to15_3_ping, b15_3to16_3_ping;
wire [`DWIDTH-1:0] b0_4to1_4_ping, b1_4to2_4_ping, b2_4to3_4_ping, b3_4to4_4_ping, b4_4to5_4_ping, b5_4to6_4_ping, b6_4to7_4_ping, b7_4to8_4_ping, b8_4to9_4_ping, b9_4to10_4_ping, b10_4to11_4_ping, b11_4to12_4_ping, b12_4to13_4_ping, b13_4to14_4_ping, b14_4to15_4_ping, b15_4to16_4_ping;
wire [`DWIDTH-1:0] b0_5to1_5_ping, b1_5to2_5_ping, b2_5to3_5_ping, b3_5to4_5_ping, b4_5to5_5_ping, b5_5to6_5_ping, b6_5to7_5_ping, b7_5to8_5_ping, b8_5to9_5_ping, b9_5to10_5_ping, b10_5to11_5_ping, b11_5to12_5_ping, b12_5to13_5_ping, b13_5to14_5_ping, b14_5to15_5_ping, b15_5to16_5_ping;
wire [`DWIDTH-1:0] b0_6to1_6_ping, b1_6to2_6_ping, b2_6to3_6_ping, b3_6to4_6_ping, b4_6to5_6_ping, b5_6to6_6_ping, b6_6to7_6_ping, b7_6to8_6_ping, b8_6to9_6_ping, b9_6to10_6_ping, b10_6to11_6_ping, b11_6to12_6_ping, b12_6to13_6_ping, b13_6to14_6_ping, b14_6to15_6_ping, b15_6to16_6_ping;
wire [`DWIDTH-1:0] b0_7to1_7_ping, b1_7to2_7_ping, b2_7to3_7_ping, b3_7to4_7_ping, b4_7to5_7_ping, b5_7to6_7_ping, b6_7to7_7_ping, b7_7to8_7_ping, b8_7to9_7_ping, b9_7to10_7_ping, b10_7to11_7_ping, b11_7to12_7_ping, b12_7to13_7_ping, b13_7to14_7_ping, b14_7to15_7_ping, b15_7to16_7_ping;
wire [`DWIDTH-1:0] b0_8to1_8_ping, b1_8to2_8_ping, b2_8to3_8_ping, b3_8to4_8_ping, b4_8to5_8_ping, b5_8to6_8_ping, b6_8to7_8_ping, b7_8to8_8_ping, b8_8to9_8_ping, b9_8to10_8_ping, b10_8to11_8_ping, b11_8to12_8_ping, b12_8to13_8_ping, b13_8to14_8_ping, b14_8to15_8_ping, b15_8to16_8_ping;
wire [`DWIDTH-1:0] b0_9to1_9_ping, b1_9to2_9_ping, b2_9to3_9_ping, b3_9to4_9_ping, b4_9to5_9_ping, b5_9to6_9_ping, b6_9to7_9_ping, b7_9to8_9_ping, b8_9to9_9_ping, b9_9to10_9_ping, b10_9to11_9_ping, b11_9to12_9_ping, b12_9to13_9_ping, b13_9to14_9_ping, b14_9to15_9_ping, b15_9to16_9_ping;
wire [`DWIDTH-1:0] b0_10to1_10_ping, b1_10to2_10_ping, b2_10to3_10_ping, b3_10to4_10_ping, b4_10to5_10_ping, b5_10to6_10_ping, b6_10to7_10_ping, b7_10to8_10_ping, b8_10to9_10_ping, b9_10to10_10_ping, b10_10to11_10_ping, b11_10to12_10_ping, b12_10to13_10_ping, b13_10to14_10_ping, b14_10to15_10_ping, b15_10to16_10_ping;
wire [`DWIDTH-1:0] b0_11to1_11_ping, b1_11to2_11_ping, b2_11to3_11_ping, b3_11to4_11_ping, b4_11to5_11_ping, b5_11to6_11_ping, b6_11to7_11_ping, b7_11to8_11_ping, b8_11to9_11_ping, b9_11to10_11_ping, b10_11to11_11_ping, b11_11to12_11_ping, b12_11to13_11_ping, b13_11to14_11_ping, b14_11to15_11_ping, b15_11to16_11_ping;
wire [`DWIDTH-1:0] b0_12to1_12_ping, b1_12to2_12_ping, b2_12to3_12_ping, b3_12to4_12_ping, b4_12to5_12_ping, b5_12to6_12_ping, b6_12to7_12_ping, b7_12to8_12_ping, b8_12to9_12_ping, b9_12to10_12_ping, b10_12to11_12_ping, b11_12to12_12_ping, b12_12to13_12_ping, b13_12to14_12_ping, b14_12to15_12_ping, b15_12to16_12_ping;
wire [`DWIDTH-1:0] b0_13to1_13_ping, b1_13to2_13_ping, b2_13to3_13_ping, b3_13to4_13_ping, b4_13to5_13_ping, b5_13to6_13_ping, b6_13to7_13_ping, b7_13to8_13_ping, b8_13to9_13_ping, b9_13to10_13_ping, b10_13to11_13_ping, b11_13to12_13_ping, b12_13to13_13_ping, b13_13to14_13_ping, b14_13to15_13_ping, b15_13to16_13_ping;
wire [`DWIDTH-1:0] b0_14to1_14_ping, b1_14to2_14_ping, b2_14to3_14_ping, b3_14to4_14_ping, b4_14to5_14_ping, b5_14to6_14_ping, b6_14to7_14_ping, b7_14to8_14_ping, b8_14to9_14_ping, b9_14to10_14_ping, b10_14to11_14_ping, b11_14to12_14_ping, b12_14to13_14_ping, b13_14to14_14_ping, b14_14to15_14_ping, b15_14to16_14_ping;
wire [`DWIDTH-1:0] b0_15to1_15_ping, b1_15to2_15_ping, b2_15to3_15_ping, b3_15to4_15_ping, b4_15to5_15_ping, b5_15to6_15_ping, b6_15to7_15_ping, b7_15to8_15_ping, b8_15to9_15_ping, b9_15to10_15_ping, b10_15to11_15_ping, b11_15to12_15_ping, b12_15to13_15_ping, b13_15to14_15_ping, b14_15to15_15_ping, b15_15to16_15_ping;

wire [`DWIDTH-1:0] b0_0to1_0_pong, b1_0to2_0_pong, b2_0to3_0_pong, b3_0to4_0_pong, b4_0to5_0_pong, b5_0to6_0_pong, b6_0to7_0_pong, b7_0to8_0_pong, b8_0to9_0_pong, b9_0to10_0_pong, b10_0to11_0_pong, b11_0to12_0_pong, b12_0to13_0_pong, b13_0to14_0_pong, b14_0to15_0_pong, b15_0to16_0_pong;
wire [`DWIDTH-1:0] b0_1to1_1_pong, b1_1to2_1_pong, b2_1to3_1_pong, b3_1to4_1_pong, b4_1to5_1_pong, b5_1to6_1_pong, b6_1to7_1_pong, b7_1to8_1_pong, b8_1to9_1_pong, b9_1to10_1_pong, b10_1to11_1_pong, b11_1to12_1_pong, b12_1to13_1_pong, b13_1to14_1_pong, b14_1to15_1_pong, b15_1to16_1_pong;
wire [`DWIDTH-1:0] b0_2to1_2_pong, b1_2to2_2_pong, b2_2to3_2_pong, b3_2to4_2_pong, b4_2to5_2_pong, b5_2to6_2_pong, b6_2to7_2_pong, b7_2to8_2_pong, b8_2to9_2_pong, b9_2to10_2_pong, b10_2to11_2_pong, b11_2to12_2_pong, b12_2to13_2_pong, b13_2to14_2_pong, b14_2to15_2_pong, b15_2to16_2_pong;
wire [`DWIDTH-1:0] b0_3to1_3_pong, b1_3to2_3_pong, b2_3to3_3_pong, b3_3to4_3_pong, b4_3to5_3_pong, b5_3to6_3_pong, b6_3to7_3_pong, b7_3to8_3_pong, b8_3to9_3_pong, b9_3to10_3_pong, b10_3to11_3_pong, b11_3to12_3_pong, b12_3to13_3_pong, b13_3to14_3_pong, b14_3to15_3_pong, b15_3to16_3_pong;
wire [`DWIDTH-1:0] b0_4to1_4_pong, b1_4to2_4_pong, b2_4to3_4_pong, b3_4to4_4_pong, b4_4to5_4_pong, b5_4to6_4_pong, b6_4to7_4_pong, b7_4to8_4_pong, b8_4to9_4_pong, b9_4to10_4_pong, b10_4to11_4_pong, b11_4to12_4_pong, b12_4to13_4_pong, b13_4to14_4_pong, b14_4to15_4_pong, b15_4to16_4_pong;
wire [`DWIDTH-1:0] b0_5to1_5_pong, b1_5to2_5_pong, b2_5to3_5_pong, b3_5to4_5_pong, b4_5to5_5_pong, b5_5to6_5_pong, b6_5to7_5_pong, b7_5to8_5_pong, b8_5to9_5_pong, b9_5to10_5_pong, b10_5to11_5_pong, b11_5to12_5_pong, b12_5to13_5_pong, b13_5to14_5_pong, b14_5to15_5_pong, b15_5to16_5_pong;
wire [`DWIDTH-1:0] b0_6to1_6_pong, b1_6to2_6_pong, b2_6to3_6_pong, b3_6to4_6_pong, b4_6to5_6_pong, b5_6to6_6_pong, b6_6to7_6_pong, b7_6to8_6_pong, b8_6to9_6_pong, b9_6to10_6_pong, b10_6to11_6_pong, b11_6to12_6_pong, b12_6to13_6_pong, b13_6to14_6_pong, b14_6to15_6_pong, b15_6to16_6_pong;
wire [`DWIDTH-1:0] b0_7to1_7_pong, b1_7to2_7_pong, b2_7to3_7_pong, b3_7to4_7_pong, b4_7to5_7_pong, b5_7to6_7_pong, b6_7to7_7_pong, b7_7to8_7_pong, b8_7to9_7_pong, b9_7to10_7_pong, b10_7to11_7_pong, b11_7to12_7_pong, b12_7to13_7_pong, b13_7to14_7_pong, b14_7to15_7_pong, b15_7to16_7_pong;
wire [`DWIDTH-1:0] b0_8to1_8_pong, b1_8to2_8_pong, b2_8to3_8_pong, b3_8to4_8_pong, b4_8to5_8_pong, b5_8to6_8_pong, b6_8to7_8_pong, b7_8to8_8_pong, b8_8to9_8_pong, b9_8to10_8_pong, b10_8to11_8_pong, b11_8to12_8_pong, b12_8to13_8_pong, b13_8to14_8_pong, b14_8to15_8_pong, b15_8to16_8_pong;
wire [`DWIDTH-1:0] b0_9to1_9_pong, b1_9to2_9_pong, b2_9to3_9_pong, b3_9to4_9_pong, b4_9to5_9_pong, b5_9to6_9_pong, b6_9to7_9_pong, b7_9to8_9_pong, b8_9to9_9_pong, b9_9to10_9_pong, b10_9to11_9_pong, b11_9to12_9_pong, b12_9to13_9_pong, b13_9to14_9_pong, b14_9to15_9_pong, b15_9to16_9_pong;
wire [`DWIDTH-1:0] b0_10to1_10_pong, b1_10to2_10_pong, b2_10to3_10_pong, b3_10to4_10_pong, b4_10to5_10_pong, b5_10to6_10_pong, b6_10to7_10_pong, b7_10to8_10_pong, b8_10to9_10_pong, b9_10to10_10_pong, b10_10to11_10_pong, b11_10to12_10_pong, b12_10to13_10_pong, b13_10to14_10_pong, b14_10to15_10_pong, b15_10to16_10_pong;
wire [`DWIDTH-1:0] b0_11to1_11_pong, b1_11to2_11_pong, b2_11to3_11_pong, b3_11to4_11_pong, b4_11to5_11_pong, b5_11to6_11_pong, b6_11to7_11_pong, b7_11to8_11_pong, b8_11to9_11_pong, b9_11to10_11_pong, b10_11to11_11_pong, b11_11to12_11_pong, b12_11to13_11_pong, b13_11to14_11_pong, b14_11to15_11_pong, b15_11to16_11_pong;
wire [`DWIDTH-1:0] b0_12to1_12_pong, b1_12to2_12_pong, b2_12to3_12_pong, b3_12to4_12_pong, b4_12to5_12_pong, b5_12to6_12_pong, b6_12to7_12_pong, b7_12to8_12_pong, b8_12to9_12_pong, b9_12to10_12_pong, b10_12to11_12_pong, b11_12to12_12_pong, b12_12to13_12_pong, b13_12to14_12_pong, b14_12to15_12_pong, b15_12to16_12_pong;
wire [`DWIDTH-1:0] b0_13to1_13_pong, b1_13to2_13_pong, b2_13to3_13_pong, b3_13to4_13_pong, b4_13to5_13_pong, b5_13to6_13_pong, b6_13to7_13_pong, b7_13to8_13_pong, b8_13to9_13_pong, b9_13to10_13_pong, b10_13to11_13_pong, b11_13to12_13_pong, b12_13to13_13_pong, b13_13to14_13_pong, b14_13to15_13_pong, b15_13to16_13_pong;
wire [`DWIDTH-1:0] b0_14to1_14_pong, b1_14to2_14_pong, b2_14to3_14_pong, b3_14to4_14_pong, b4_14to5_14_pong, b5_14to6_14_pong, b6_14to7_14_pong, b7_14to8_14_pong, b8_14to9_14_pong, b9_14to10_14_pong, b10_14to11_14_pong, b11_14to12_14_pong, b12_14to13_14_pong, b13_14to14_14_pong, b14_14to15_14_pong, b15_14to16_14_pong;
wire [`DWIDTH-1:0] b0_15to1_15_pong, b1_15to2_15_pong, b2_15to3_15_pong, b3_15to4_15_pong, b4_15to5_15_pong, b5_15to6_15_pong, b6_15to7_15_pong, b7_15to8_15_pong, b8_15to9_15_pong, b9_15to10_15_pong, b10_15to11_15_pong, b11_15to12_15_pong, b12_15to13_15_pong, b13_15to14_15_pong, b14_15to15_15_pong, b15_15to16_15_pong;

reg [`DWIDTH-1:0] b0_data, b1_data, b2_data, b3_data, b4_data, b5_data, b6_data, b7_data, b8_data, b9_data, b10_data, b11_data, b12_data, b13_data, b14_data, b15_data; 

wire effective_rst;
assign effective_rst = reset | pe_reset;

reg b_data_sel_delay1;
reg b_data_sel_delay2;
reg b_data_sel_delay3;
reg b_data_sel_delay4;
reg b_data_sel_delay5;
reg b_data_sel_delay6;
reg b_data_sel_delay7;
reg b_data_sel_delay8;
reg b_data_sel_delay9;
reg b_data_sel_delay10;
reg b_data_sel_delay11;
reg b_data_sel_delay12;
reg b_data_sel_delay13;
reg b_data_sel_delay14;
reg b_data_sel_delay15;
reg b_data_sel_delay16;
reg b_data_sel_delay17;
reg b_data_sel_delay18;
reg b_data_sel_delay19;
reg b_data_sel_delay20;
reg b_data_sel_delay21;
reg b_data_sel_delay22;
reg b_data_sel_delay23;
reg b_data_sel_delay24;
reg b_data_sel_delay25;
reg b_data_sel_delay26;
reg b_data_sel_delay27;
reg b_data_sel_delay28;
reg b_data_sel_delay29;
reg b_data_sel_delay30;

always @ (posedge clk) begin
    if (reset) begin
        b_data_sel_delay1 <= 0;
        b_data_sel_delay2 <= 0;
        b_data_sel_delay3 <= 0;
        b_data_sel_delay4 <= 0;
        b_data_sel_delay5 <= 0;
        b_data_sel_delay6 <= 0;
        b_data_sel_delay7 <= 0;
        b_data_sel_delay8 <= 0;
        b_data_sel_delay9 <= 0;
        b_data_sel_delay10 <= 0;
        b_data_sel_delay11 <= 0;
        b_data_sel_delay12 <= 0;
        b_data_sel_delay13 <= 0;
        b_data_sel_delay14 <= 0;
        b_data_sel_delay15 <= 0;
        b_data_sel_delay16 <= 0;
        b_data_sel_delay17 <= 0;
        b_data_sel_delay18 <= 0;
        b_data_sel_delay19 <= 0;
        b_data_sel_delay20 <= 0;
        b_data_sel_delay21 <= 0;
        b_data_sel_delay22 <= 0;
        b_data_sel_delay23 <= 0;
        b_data_sel_delay24 <= 0;
        b_data_sel_delay25 <= 0;
        b_data_sel_delay26 <= 0;
        b_data_sel_delay27 <= 0;
        b_data_sel_delay28 <= 0;
        b_data_sel_delay29 <= 0;
        b_data_sel_delay30 <= 0;
    end
    else begin
        b_data_sel_delay1 <= b_data_sel;
        b_data_sel_delay2 <= b_data_sel_delay1;
        b_data_sel_delay3 <= b_data_sel_delay2;
        b_data_sel_delay4 <= b_data_sel_delay3;
        b_data_sel_delay5 <= b_data_sel_delay4;
        b_data_sel_delay6 <= b_data_sel_delay5;
        b_data_sel_delay7 <= b_data_sel_delay6;
        b_data_sel_delay8 <= b_data_sel_delay7;
        b_data_sel_delay9 <= b_data_sel_delay8;
        b_data_sel_delay10 <= b_data_sel_delay9;
        b_data_sel_delay11 <= b_data_sel_delay10;
        b_data_sel_delay12 <= b_data_sel_delay11;
        b_data_sel_delay13 <= b_data_sel_delay12;
        b_data_sel_delay14 <= b_data_sel_delay13;
        b_data_sel_delay15 <= b_data_sel_delay14;
        b_data_sel_delay16 <= b_data_sel_delay15;
        b_data_sel_delay17 <= b_data_sel_delay16;
        b_data_sel_delay18 <= b_data_sel_delay17;
        b_data_sel_delay19 <= b_data_sel_delay18;
        b_data_sel_delay20 <= b_data_sel_delay19;
        b_data_sel_delay21 <= b_data_sel_delay20;
        b_data_sel_delay22 <= b_data_sel_delay21;
        b_data_sel_delay23 <= b_data_sel_delay22;
        b_data_sel_delay24 <= b_data_sel_delay23;
        b_data_sel_delay25 <= b_data_sel_delay24;
        b_data_sel_delay26 <= b_data_sel_delay25;
        b_data_sel_delay27 <= b_data_sel_delay26;
        b_data_sel_delay28 <= b_data_sel_delay27;
        b_data_sel_delay29 <= b_data_sel_delay28;
        b_data_sel_delay30 <= b_data_sel_delay29;
  	end
end

// Signals for Each PONG buffer

reg b_data_valid_pong_delay0_1;
reg b_data_valid_pong_delay0_2;
reg b_data_valid_pong_delay0_3;
reg b_data_valid_pong_delay0_4;
reg b_data_valid_pong_delay0_5;
reg b_data_valid_pong_delay0_6;
reg b_data_valid_pong_delay0_7;
reg b_data_valid_pong_delay0_8;
reg b_data_valid_pong_delay0_9;
reg b_data_valid_pong_delay0_10;
reg b_data_valid_pong_delay0_11;
reg b_data_valid_pong_delay0_12;
reg b_data_valid_pong_delay0_13;
reg b_data_valid_pong_delay0_14;
reg b_data_valid_pong_delay0_15;
reg b_data_valid_pong_delay0_16;
reg b_data_valid_pong_delay0_17;
reg b_data_valid_pong_delay0_18;
reg b_data_valid_pong_delay0_19;
reg b_data_valid_pong_delay0_20;
reg b_data_valid_pong_delay0_21;
reg b_data_valid_pong_delay0_22;
reg b_data_valid_pong_delay0_23;
reg b_data_valid_pong_delay0_24;
reg b_data_valid_pong_delay0_25;
reg b_data_valid_pong_delay0_26;
reg b_data_valid_pong_delay0_27;
reg b_data_valid_pong_delay0_28;
reg b_data_valid_pong_delay0_29;
reg b_data_valid_pong_delay0_30;
wire b_data_valid_pong_delay1_0;
wire b_data_valid_pong_delay2_0;
wire b_data_valid_pong_delay3_0;
wire b_data_valid_pong_delay4_0;
wire b_data_valid_pong_delay5_0;
wire b_data_valid_pong_delay6_0;
wire b_data_valid_pong_delay7_0;
wire b_data_valid_pong_delay8_0;
wire b_data_valid_pong_delay9_0;
wire b_data_valid_pong_delay10_0;
wire b_data_valid_pong_delay11_0;
wire b_data_valid_pong_delay12_0;
wire b_data_valid_pong_delay13_0;
wire b_data_valid_pong_delay14_0;
wire b_data_valid_pong_delay15_0;
wire b_data_valid_pong_delay1_1;
wire b_data_valid_pong_delay2_1;
wire b_data_valid_pong_delay3_1;
wire b_data_valid_pong_delay4_1;
wire b_data_valid_pong_delay5_1;
wire b_data_valid_pong_delay6_1;
wire b_data_valid_pong_delay7_1;
wire b_data_valid_pong_delay8_1;
wire b_data_valid_pong_delay9_1;
wire b_data_valid_pong_delay10_1;
wire b_data_valid_pong_delay11_1;
wire b_data_valid_pong_delay12_1;
wire b_data_valid_pong_delay13_1;
wire b_data_valid_pong_delay14_1;
wire b_data_valid_pong_delay15_1;
wire b_data_valid_pong_delay1_2;
wire b_data_valid_pong_delay2_2;
wire b_data_valid_pong_delay3_2;
wire b_data_valid_pong_delay4_2;
wire b_data_valid_pong_delay5_2;
wire b_data_valid_pong_delay6_2;
wire b_data_valid_pong_delay7_2;
wire b_data_valid_pong_delay8_2;
wire b_data_valid_pong_delay9_2;
wire b_data_valid_pong_delay10_2;
wire b_data_valid_pong_delay11_2;
wire b_data_valid_pong_delay12_2;
wire b_data_valid_pong_delay13_2;
wire b_data_valid_pong_delay14_2;
wire b_data_valid_pong_delay15_2;
wire b_data_valid_pong_delay1_3;
wire b_data_valid_pong_delay2_3;
wire b_data_valid_pong_delay3_3;
wire b_data_valid_pong_delay4_3;
wire b_data_valid_pong_delay5_3;
wire b_data_valid_pong_delay6_3;
wire b_data_valid_pong_delay7_3;
wire b_data_valid_pong_delay8_3;
wire b_data_valid_pong_delay9_3;
wire b_data_valid_pong_delay10_3;
wire b_data_valid_pong_delay11_3;
wire b_data_valid_pong_delay12_3;
wire b_data_valid_pong_delay13_3;
wire b_data_valid_pong_delay14_3;
wire b_data_valid_pong_delay15_3;
wire b_data_valid_pong_delay1_4;
wire b_data_valid_pong_delay2_4;
wire b_data_valid_pong_delay3_4;
wire b_data_valid_pong_delay4_4;
wire b_data_valid_pong_delay5_4;
wire b_data_valid_pong_delay6_4;
wire b_data_valid_pong_delay7_4;
wire b_data_valid_pong_delay8_4;
wire b_data_valid_pong_delay9_4;
wire b_data_valid_pong_delay10_4;
wire b_data_valid_pong_delay11_4;
wire b_data_valid_pong_delay12_4;
wire b_data_valid_pong_delay13_4;
wire b_data_valid_pong_delay14_4;
wire b_data_valid_pong_delay15_4;
wire b_data_valid_pong_delay1_5;
wire b_data_valid_pong_delay2_5;
wire b_data_valid_pong_delay3_5;
wire b_data_valid_pong_delay4_5;
wire b_data_valid_pong_delay5_5;
wire b_data_valid_pong_delay6_5;
wire b_data_valid_pong_delay7_5;
wire b_data_valid_pong_delay8_5;
wire b_data_valid_pong_delay9_5;
wire b_data_valid_pong_delay10_5;
wire b_data_valid_pong_delay11_5;
wire b_data_valid_pong_delay12_5;
wire b_data_valid_pong_delay13_5;
wire b_data_valid_pong_delay14_5;
wire b_data_valid_pong_delay15_5;
wire b_data_valid_pong_delay1_6;
wire b_data_valid_pong_delay2_6;
wire b_data_valid_pong_delay3_6;
wire b_data_valid_pong_delay4_6;
wire b_data_valid_pong_delay5_6;
wire b_data_valid_pong_delay6_6;
wire b_data_valid_pong_delay7_6;
wire b_data_valid_pong_delay8_6;
wire b_data_valid_pong_delay9_6;
wire b_data_valid_pong_delay10_6;
wire b_data_valid_pong_delay11_6;
wire b_data_valid_pong_delay12_6;
wire b_data_valid_pong_delay13_6;
wire b_data_valid_pong_delay14_6;
wire b_data_valid_pong_delay15_6;
wire b_data_valid_pong_delay1_7;
wire b_data_valid_pong_delay2_7;
wire b_data_valid_pong_delay3_7;
wire b_data_valid_pong_delay4_7;
wire b_data_valid_pong_delay5_7;
wire b_data_valid_pong_delay6_7;
wire b_data_valid_pong_delay7_7;
wire b_data_valid_pong_delay8_7;
wire b_data_valid_pong_delay9_7;
wire b_data_valid_pong_delay10_7;
wire b_data_valid_pong_delay11_7;
wire b_data_valid_pong_delay12_7;
wire b_data_valid_pong_delay13_7;
wire b_data_valid_pong_delay14_7;
wire b_data_valid_pong_delay15_7;
wire b_data_valid_pong_delay1_8;
wire b_data_valid_pong_delay2_8;
wire b_data_valid_pong_delay3_8;
wire b_data_valid_pong_delay4_8;
wire b_data_valid_pong_delay5_8;
wire b_data_valid_pong_delay6_8;
wire b_data_valid_pong_delay7_8;
wire b_data_valid_pong_delay8_8;
wire b_data_valid_pong_delay9_8;
wire b_data_valid_pong_delay10_8;
wire b_data_valid_pong_delay11_8;
wire b_data_valid_pong_delay12_8;
wire b_data_valid_pong_delay13_8;
wire b_data_valid_pong_delay14_8;
wire b_data_valid_pong_delay15_8;
wire b_data_valid_pong_delay1_9;
wire b_data_valid_pong_delay2_9;
wire b_data_valid_pong_delay3_9;
wire b_data_valid_pong_delay4_9;
wire b_data_valid_pong_delay5_9;
wire b_data_valid_pong_delay6_9;
wire b_data_valid_pong_delay7_9;
wire b_data_valid_pong_delay8_9;
wire b_data_valid_pong_delay9_9;
wire b_data_valid_pong_delay10_9;
wire b_data_valid_pong_delay11_9;
wire b_data_valid_pong_delay12_9;
wire b_data_valid_pong_delay13_9;
wire b_data_valid_pong_delay14_9;
wire b_data_valid_pong_delay15_9;
wire b_data_valid_pong_delay1_10;
wire b_data_valid_pong_delay2_10;
wire b_data_valid_pong_delay3_10;
wire b_data_valid_pong_delay4_10;
wire b_data_valid_pong_delay5_10;
wire b_data_valid_pong_delay6_10;
wire b_data_valid_pong_delay7_10;
wire b_data_valid_pong_delay8_10;
wire b_data_valid_pong_delay9_10;
wire b_data_valid_pong_delay10_10;
wire b_data_valid_pong_delay11_10;
wire b_data_valid_pong_delay12_10;
wire b_data_valid_pong_delay13_10;
wire b_data_valid_pong_delay14_10;
wire b_data_valid_pong_delay15_10;
wire b_data_valid_pong_delay1_11;
wire b_data_valid_pong_delay2_11;
wire b_data_valid_pong_delay3_11;
wire b_data_valid_pong_delay4_11;
wire b_data_valid_pong_delay5_11;
wire b_data_valid_pong_delay6_11;
wire b_data_valid_pong_delay7_11;
wire b_data_valid_pong_delay8_11;
wire b_data_valid_pong_delay9_11;
wire b_data_valid_pong_delay10_11;
wire b_data_valid_pong_delay11_11;
wire b_data_valid_pong_delay12_11;
wire b_data_valid_pong_delay13_11;
wire b_data_valid_pong_delay14_11;
wire b_data_valid_pong_delay15_11;
wire b_data_valid_pong_delay1_12;
wire b_data_valid_pong_delay2_12;
wire b_data_valid_pong_delay3_12;
wire b_data_valid_pong_delay4_12;
wire b_data_valid_pong_delay5_12;
wire b_data_valid_pong_delay6_12;
wire b_data_valid_pong_delay7_12;
wire b_data_valid_pong_delay8_12;
wire b_data_valid_pong_delay9_12;
wire b_data_valid_pong_delay10_12;
wire b_data_valid_pong_delay11_12;
wire b_data_valid_pong_delay12_12;
wire b_data_valid_pong_delay13_12;
wire b_data_valid_pong_delay14_12;
wire b_data_valid_pong_delay15_12;
wire b_data_valid_pong_delay1_13;
wire b_data_valid_pong_delay2_13;
wire b_data_valid_pong_delay3_13;
wire b_data_valid_pong_delay4_13;
wire b_data_valid_pong_delay5_13;
wire b_data_valid_pong_delay6_13;
wire b_data_valid_pong_delay7_13;
wire b_data_valid_pong_delay8_13;
wire b_data_valid_pong_delay9_13;
wire b_data_valid_pong_delay10_13;
wire b_data_valid_pong_delay11_13;
wire b_data_valid_pong_delay12_13;
wire b_data_valid_pong_delay13_13;
wire b_data_valid_pong_delay14_13;
wire b_data_valid_pong_delay15_13;
wire b_data_valid_pong_delay1_14;
wire b_data_valid_pong_delay2_14;
wire b_data_valid_pong_delay3_14;
wire b_data_valid_pong_delay4_14;
wire b_data_valid_pong_delay5_14;
wire b_data_valid_pong_delay6_14;
wire b_data_valid_pong_delay7_14;
wire b_data_valid_pong_delay8_14;
wire b_data_valid_pong_delay9_14;
wire b_data_valid_pong_delay10_14;
wire b_data_valid_pong_delay11_14;
wire b_data_valid_pong_delay12_14;
wire b_data_valid_pong_delay13_14;
wire b_data_valid_pong_delay14_14;
wire b_data_valid_pong_delay15_14;
wire b_data_valid_pong_delay1_15;
wire b_data_valid_pong_delay2_15;
wire b_data_valid_pong_delay3_15;
wire b_data_valid_pong_delay4_15;
wire b_data_valid_pong_delay5_15;
wire b_data_valid_pong_delay6_15;
wire b_data_valid_pong_delay7_15;
wire b_data_valid_pong_delay8_15;
wire b_data_valid_pong_delay9_15;
wire b_data_valid_pong_delay10_15;
wire b_data_valid_pong_delay11_15;
wire b_data_valid_pong_delay12_15;
wire b_data_valid_pong_delay13_15;
wire b_data_valid_pong_delay14_15;
wire b_data_valid_pong_delay15_15;
  
always @ (posedge clk) begin
    b_data_valid_pong_delay0_1 <= b_data_valid_pong;
    b_data_valid_pong_delay0_2 <= b_data_valid_pong_delay0_1;
    b_data_valid_pong_delay0_3 <= b_data_valid_pong_delay0_2;
    b_data_valid_pong_delay0_4 <= b_data_valid_pong_delay0_3;
    b_data_valid_pong_delay0_5 <= b_data_valid_pong_delay0_4;
    b_data_valid_pong_delay0_6 <= b_data_valid_pong_delay0_5;
    b_data_valid_pong_delay0_7 <= b_data_valid_pong_delay0_6;
    b_data_valid_pong_delay0_8 <= b_data_valid_pong_delay0_7;
    b_data_valid_pong_delay0_9 <= b_data_valid_pong_delay0_8;
    b_data_valid_pong_delay0_10 <= b_data_valid_pong_delay0_9;
    b_data_valid_pong_delay0_11 <= b_data_valid_pong_delay0_10;
    b_data_valid_pong_delay0_12 <= b_data_valid_pong_delay0_11;
    b_data_valid_pong_delay0_13 <= b_data_valid_pong_delay0_12;
    b_data_valid_pong_delay0_14 <= b_data_valid_pong_delay0_13;
    b_data_valid_pong_delay0_15 <= b_data_valid_pong_delay0_14;
    b_data_valid_pong_delay0_16 <= b_data_valid_pong_delay0_15;
    b_data_valid_pong_delay0_17 <= b_data_valid_pong_delay0_16;
    b_data_valid_pong_delay0_18 <= b_data_valid_pong_delay0_17;
    b_data_valid_pong_delay0_19 <= b_data_valid_pong_delay0_18;
    b_data_valid_pong_delay0_20 <= b_data_valid_pong_delay0_19;
    b_data_valid_pong_delay0_21 <= b_data_valid_pong_delay0_20;
    b_data_valid_pong_delay0_22 <= b_data_valid_pong_delay0_21;
    b_data_valid_pong_delay0_23 <= b_data_valid_pong_delay0_22;
    b_data_valid_pong_delay0_24 <= b_data_valid_pong_delay0_23;
    b_data_valid_pong_delay0_25 <= b_data_valid_pong_delay0_24;
    b_data_valid_pong_delay0_26 <= b_data_valid_pong_delay0_25;
    b_data_valid_pong_delay0_27 <= b_data_valid_pong_delay0_26;
    b_data_valid_pong_delay0_28 <= b_data_valid_pong_delay0_27;
    b_data_valid_pong_delay0_29 <= b_data_valid_pong_delay0_28;
    b_data_valid_pong_delay0_30 <= b_data_valid_pong_delay0_29;
end

assign b_data_valid_pong_delay1_0 = b_data_valid_pong & b_data_valid_pong_delay0_1;
assign b_data_valid_pong_delay2_0 = b_data_valid_pong & b_data_valid_pong_delay0_2;
assign b_data_valid_pong_delay3_0 = b_data_valid_pong & b_data_valid_pong_delay0_3;
assign b_data_valid_pong_delay4_0 = b_data_valid_pong & b_data_valid_pong_delay0_4;
assign b_data_valid_pong_delay5_0 = b_data_valid_pong & b_data_valid_pong_delay0_5;
assign b_data_valid_pong_delay6_0 = b_data_valid_pong & b_data_valid_pong_delay0_6;
assign b_data_valid_pong_delay7_0 = b_data_valid_pong & b_data_valid_pong_delay0_7;
assign b_data_valid_pong_delay8_0 = b_data_valid_pong & b_data_valid_pong_delay0_8;
assign b_data_valid_pong_delay9_0 = b_data_valid_pong & b_data_valid_pong_delay0_9;
assign b_data_valid_pong_delay10_0 = b_data_valid_pong & b_data_valid_pong_delay0_10;
assign b_data_valid_pong_delay11_0 = b_data_valid_pong & b_data_valid_pong_delay0_11;
assign b_data_valid_pong_delay12_0 = b_data_valid_pong & b_data_valid_pong_delay0_12;
assign b_data_valid_pong_delay13_0 = b_data_valid_pong & b_data_valid_pong_delay0_13;
assign b_data_valid_pong_delay14_0 = b_data_valid_pong & b_data_valid_pong_delay0_14;
assign b_data_valid_pong_delay15_0 = b_data_valid_pong & b_data_valid_pong_delay0_15;
assign b_data_valid_pong_delay1_1 = b_data_valid_pong_delay0_1 & b_data_valid_pong_delay0_2;
assign b_data_valid_pong_delay2_1 = b_data_valid_pong_delay0_1 & b_data_valid_pong_delay0_3;
assign b_data_valid_pong_delay3_1 = b_data_valid_pong_delay0_1 & b_data_valid_pong_delay0_4;
assign b_data_valid_pong_delay4_1 = b_data_valid_pong_delay0_1 & b_data_valid_pong_delay0_5;
assign b_data_valid_pong_delay5_1 = b_data_valid_pong_delay0_1 & b_data_valid_pong_delay0_6;
assign b_data_valid_pong_delay6_1 = b_data_valid_pong_delay0_1 & b_data_valid_pong_delay0_7;
assign b_data_valid_pong_delay7_1 = b_data_valid_pong_delay0_1 & b_data_valid_pong_delay0_8;
assign b_data_valid_pong_delay8_1 = b_data_valid_pong_delay0_1 & b_data_valid_pong_delay0_9;
assign b_data_valid_pong_delay9_1 = b_data_valid_pong_delay0_1 & b_data_valid_pong_delay0_10;
assign b_data_valid_pong_delay10_1 = b_data_valid_pong_delay0_1 & b_data_valid_pong_delay0_11;
assign b_data_valid_pong_delay11_1 = b_data_valid_pong_delay0_1 & b_data_valid_pong_delay0_12;
assign b_data_valid_pong_delay12_1 = b_data_valid_pong_delay0_1 & b_data_valid_pong_delay0_13;
assign b_data_valid_pong_delay13_1 = b_data_valid_pong_delay0_1 & b_data_valid_pong_delay0_14;
assign b_data_valid_pong_delay14_1 = b_data_valid_pong_delay0_1 & b_data_valid_pong_delay0_15;
assign b_data_valid_pong_delay15_1 = b_data_valid_pong_delay0_1 & b_data_valid_pong_delay0_16;
assign b_data_valid_pong_delay1_2 = b_data_valid_pong_delay0_2 & b_data_valid_pong_delay0_3;
assign b_data_valid_pong_delay2_2 = b_data_valid_pong_delay0_2 & b_data_valid_pong_delay0_4;
assign b_data_valid_pong_delay3_2 = b_data_valid_pong_delay0_2 & b_data_valid_pong_delay0_5;
assign b_data_valid_pong_delay4_2 = b_data_valid_pong_delay0_2 & b_data_valid_pong_delay0_6;
assign b_data_valid_pong_delay5_2 = b_data_valid_pong_delay0_2 & b_data_valid_pong_delay0_7;
assign b_data_valid_pong_delay6_2 = b_data_valid_pong_delay0_2 & b_data_valid_pong_delay0_8;
assign b_data_valid_pong_delay7_2 = b_data_valid_pong_delay0_2 & b_data_valid_pong_delay0_9;
assign b_data_valid_pong_delay8_2 = b_data_valid_pong_delay0_2 & b_data_valid_pong_delay0_10;
assign b_data_valid_pong_delay9_2 = b_data_valid_pong_delay0_2 & b_data_valid_pong_delay0_11;
assign b_data_valid_pong_delay10_2 = b_data_valid_pong_delay0_2 & b_data_valid_pong_delay0_12;
assign b_data_valid_pong_delay11_2 = b_data_valid_pong_delay0_2 & b_data_valid_pong_delay0_13;
assign b_data_valid_pong_delay12_2 = b_data_valid_pong_delay0_2 & b_data_valid_pong_delay0_14;
assign b_data_valid_pong_delay13_2 = b_data_valid_pong_delay0_2 & b_data_valid_pong_delay0_15;
assign b_data_valid_pong_delay14_2 = b_data_valid_pong_delay0_2 & b_data_valid_pong_delay0_16;
assign b_data_valid_pong_delay15_2 = b_data_valid_pong_delay0_2 & b_data_valid_pong_delay0_17;
assign b_data_valid_pong_delay1_3 = b_data_valid_pong_delay0_3 & b_data_valid_pong_delay0_4;
assign b_data_valid_pong_delay2_3 = b_data_valid_pong_delay0_3 & b_data_valid_pong_delay0_5;
assign b_data_valid_pong_delay3_3 = b_data_valid_pong_delay0_3 & b_data_valid_pong_delay0_6;
assign b_data_valid_pong_delay4_3 = b_data_valid_pong_delay0_3 & b_data_valid_pong_delay0_7;
assign b_data_valid_pong_delay5_3 = b_data_valid_pong_delay0_3 & b_data_valid_pong_delay0_8;
assign b_data_valid_pong_delay6_3 = b_data_valid_pong_delay0_3 & b_data_valid_pong_delay0_9;
assign b_data_valid_pong_delay7_3 = b_data_valid_pong_delay0_3 & b_data_valid_pong_delay0_10;
assign b_data_valid_pong_delay8_3 = b_data_valid_pong_delay0_3 & b_data_valid_pong_delay0_11;
assign b_data_valid_pong_delay9_3 = b_data_valid_pong_delay0_3 & b_data_valid_pong_delay0_12;
assign b_data_valid_pong_delay10_3 = b_data_valid_pong_delay0_3 & b_data_valid_pong_delay0_13;
assign b_data_valid_pong_delay11_3 = b_data_valid_pong_delay0_3 & b_data_valid_pong_delay0_14;
assign b_data_valid_pong_delay12_3 = b_data_valid_pong_delay0_3 & b_data_valid_pong_delay0_15;
assign b_data_valid_pong_delay13_3 = b_data_valid_pong_delay0_3 & b_data_valid_pong_delay0_16;
assign b_data_valid_pong_delay14_3 = b_data_valid_pong_delay0_3 & b_data_valid_pong_delay0_17;
assign b_data_valid_pong_delay15_3 = b_data_valid_pong_delay0_3 & b_data_valid_pong_delay0_18;
assign b_data_valid_pong_delay1_4 = b_data_valid_pong_delay0_4 & b_data_valid_pong_delay0_5;
assign b_data_valid_pong_delay2_4 = b_data_valid_pong_delay0_4 & b_data_valid_pong_delay0_6;
assign b_data_valid_pong_delay3_4 = b_data_valid_pong_delay0_4 & b_data_valid_pong_delay0_7;
assign b_data_valid_pong_delay4_4 = b_data_valid_pong_delay0_4 & b_data_valid_pong_delay0_8;
assign b_data_valid_pong_delay5_4 = b_data_valid_pong_delay0_4 & b_data_valid_pong_delay0_9;
assign b_data_valid_pong_delay6_4 = b_data_valid_pong_delay0_4 & b_data_valid_pong_delay0_10;
assign b_data_valid_pong_delay7_4 = b_data_valid_pong_delay0_4 & b_data_valid_pong_delay0_11;
assign b_data_valid_pong_delay8_4 = b_data_valid_pong_delay0_4 & b_data_valid_pong_delay0_12;
assign b_data_valid_pong_delay9_4 = b_data_valid_pong_delay0_4 & b_data_valid_pong_delay0_13;
assign b_data_valid_pong_delay10_4 = b_data_valid_pong_delay0_4 & b_data_valid_pong_delay0_14;
assign b_data_valid_pong_delay11_4 = b_data_valid_pong_delay0_4 & b_data_valid_pong_delay0_15;
assign b_data_valid_pong_delay12_4 = b_data_valid_pong_delay0_4 & b_data_valid_pong_delay0_16;
assign b_data_valid_pong_delay13_4 = b_data_valid_pong_delay0_4 & b_data_valid_pong_delay0_17;
assign b_data_valid_pong_delay14_4 = b_data_valid_pong_delay0_4 & b_data_valid_pong_delay0_18;
assign b_data_valid_pong_delay15_4 = b_data_valid_pong_delay0_4 & b_data_valid_pong_delay0_19;
assign b_data_valid_pong_delay1_5 = b_data_valid_pong_delay0_5 & b_data_valid_pong_delay0_6;
assign b_data_valid_pong_delay2_5 = b_data_valid_pong_delay0_5 & b_data_valid_pong_delay0_7;
assign b_data_valid_pong_delay3_5 = b_data_valid_pong_delay0_5 & b_data_valid_pong_delay0_8;
assign b_data_valid_pong_delay4_5 = b_data_valid_pong_delay0_5 & b_data_valid_pong_delay0_9;
assign b_data_valid_pong_delay5_5 = b_data_valid_pong_delay0_5 & b_data_valid_pong_delay0_10;
assign b_data_valid_pong_delay6_5 = b_data_valid_pong_delay0_5 & b_data_valid_pong_delay0_11;
assign b_data_valid_pong_delay7_5 = b_data_valid_pong_delay0_5 & b_data_valid_pong_delay0_12;
assign b_data_valid_pong_delay8_5 = b_data_valid_pong_delay0_5 & b_data_valid_pong_delay0_13;
assign b_data_valid_pong_delay9_5 = b_data_valid_pong_delay0_5 & b_data_valid_pong_delay0_14;
assign b_data_valid_pong_delay10_5 = b_data_valid_pong_delay0_5 & b_data_valid_pong_delay0_15;
assign b_data_valid_pong_delay11_5 = b_data_valid_pong_delay0_5 & b_data_valid_pong_delay0_16;
assign b_data_valid_pong_delay12_5 = b_data_valid_pong_delay0_5 & b_data_valid_pong_delay0_17;
assign b_data_valid_pong_delay13_5 = b_data_valid_pong_delay0_5 & b_data_valid_pong_delay0_18;
assign b_data_valid_pong_delay14_5 = b_data_valid_pong_delay0_5 & b_data_valid_pong_delay0_19;
assign b_data_valid_pong_delay15_5 = b_data_valid_pong_delay0_5 & b_data_valid_pong_delay0_20;
assign b_data_valid_pong_delay1_6 = b_data_valid_pong_delay0_6 & b_data_valid_pong_delay0_7;
assign b_data_valid_pong_delay2_6 = b_data_valid_pong_delay0_6 & b_data_valid_pong_delay0_8;
assign b_data_valid_pong_delay3_6 = b_data_valid_pong_delay0_6 & b_data_valid_pong_delay0_9;
assign b_data_valid_pong_delay4_6 = b_data_valid_pong_delay0_6 & b_data_valid_pong_delay0_10;
assign b_data_valid_pong_delay5_6 = b_data_valid_pong_delay0_6 & b_data_valid_pong_delay0_11;
assign b_data_valid_pong_delay6_6 = b_data_valid_pong_delay0_6 & b_data_valid_pong_delay0_12;
assign b_data_valid_pong_delay7_6 = b_data_valid_pong_delay0_6 & b_data_valid_pong_delay0_13;
assign b_data_valid_pong_delay8_6 = b_data_valid_pong_delay0_6 & b_data_valid_pong_delay0_14;
assign b_data_valid_pong_delay9_6 = b_data_valid_pong_delay0_6 & b_data_valid_pong_delay0_15;
assign b_data_valid_pong_delay10_6 = b_data_valid_pong_delay0_6 & b_data_valid_pong_delay0_16;
assign b_data_valid_pong_delay11_6 = b_data_valid_pong_delay0_6 & b_data_valid_pong_delay0_17;
assign b_data_valid_pong_delay12_6 = b_data_valid_pong_delay0_6 & b_data_valid_pong_delay0_18;
assign b_data_valid_pong_delay13_6 = b_data_valid_pong_delay0_6 & b_data_valid_pong_delay0_19;
assign b_data_valid_pong_delay14_6 = b_data_valid_pong_delay0_6 & b_data_valid_pong_delay0_20;
assign b_data_valid_pong_delay15_6 = b_data_valid_pong_delay0_6 & b_data_valid_pong_delay0_21;
assign b_data_valid_pong_delay1_7 = b_data_valid_pong_delay0_7 & b_data_valid_pong_delay0_8;
assign b_data_valid_pong_delay2_7 = b_data_valid_pong_delay0_7 & b_data_valid_pong_delay0_9;
assign b_data_valid_pong_delay3_7 = b_data_valid_pong_delay0_7 & b_data_valid_pong_delay0_10;
assign b_data_valid_pong_delay4_7 = b_data_valid_pong_delay0_7 & b_data_valid_pong_delay0_11;
assign b_data_valid_pong_delay5_7 = b_data_valid_pong_delay0_7 & b_data_valid_pong_delay0_12;
assign b_data_valid_pong_delay6_7 = b_data_valid_pong_delay0_7 & b_data_valid_pong_delay0_13;
assign b_data_valid_pong_delay7_7 = b_data_valid_pong_delay0_7 & b_data_valid_pong_delay0_14;
assign b_data_valid_pong_delay8_7 = b_data_valid_pong_delay0_7 & b_data_valid_pong_delay0_15;
assign b_data_valid_pong_delay9_7 = b_data_valid_pong_delay0_7 & b_data_valid_pong_delay0_16;
assign b_data_valid_pong_delay10_7 = b_data_valid_pong_delay0_7 & b_data_valid_pong_delay0_17;
assign b_data_valid_pong_delay11_7 = b_data_valid_pong_delay0_7 & b_data_valid_pong_delay0_18;
assign b_data_valid_pong_delay12_7 = b_data_valid_pong_delay0_7 & b_data_valid_pong_delay0_19;
assign b_data_valid_pong_delay13_7 = b_data_valid_pong_delay0_7 & b_data_valid_pong_delay0_20;
assign b_data_valid_pong_delay14_7 = b_data_valid_pong_delay0_7 & b_data_valid_pong_delay0_21;
assign b_data_valid_pong_delay15_7 = b_data_valid_pong_delay0_7 & b_data_valid_pong_delay0_22;
assign b_data_valid_pong_delay1_8 = b_data_valid_pong_delay0_8 & b_data_valid_pong_delay0_9;
assign b_data_valid_pong_delay2_8 = b_data_valid_pong_delay0_8 & b_data_valid_pong_delay0_10;
assign b_data_valid_pong_delay3_8 = b_data_valid_pong_delay0_8 & b_data_valid_pong_delay0_11;
assign b_data_valid_pong_delay4_8 = b_data_valid_pong_delay0_8 & b_data_valid_pong_delay0_12;
assign b_data_valid_pong_delay5_8 = b_data_valid_pong_delay0_8 & b_data_valid_pong_delay0_13;
assign b_data_valid_pong_delay6_8 = b_data_valid_pong_delay0_8 & b_data_valid_pong_delay0_14;
assign b_data_valid_pong_delay7_8 = b_data_valid_pong_delay0_8 & b_data_valid_pong_delay0_15;
assign b_data_valid_pong_delay8_8 = b_data_valid_pong_delay0_8 & b_data_valid_pong_delay0_16;
assign b_data_valid_pong_delay9_8 = b_data_valid_pong_delay0_8 & b_data_valid_pong_delay0_17;
assign b_data_valid_pong_delay10_8 = b_data_valid_pong_delay0_8 & b_data_valid_pong_delay0_18;
assign b_data_valid_pong_delay11_8 = b_data_valid_pong_delay0_8 & b_data_valid_pong_delay0_19;
assign b_data_valid_pong_delay12_8 = b_data_valid_pong_delay0_8 & b_data_valid_pong_delay0_20;
assign b_data_valid_pong_delay13_8 = b_data_valid_pong_delay0_8 & b_data_valid_pong_delay0_21;
assign b_data_valid_pong_delay14_8 = b_data_valid_pong_delay0_8 & b_data_valid_pong_delay0_22;
assign b_data_valid_pong_delay15_8 = b_data_valid_pong_delay0_8 & b_data_valid_pong_delay0_23;
assign b_data_valid_pong_delay1_9 = b_data_valid_pong_delay0_9 & b_data_valid_pong_delay0_10;
assign b_data_valid_pong_delay2_9 = b_data_valid_pong_delay0_9 & b_data_valid_pong_delay0_11;
assign b_data_valid_pong_delay3_9 = b_data_valid_pong_delay0_9 & b_data_valid_pong_delay0_12;
assign b_data_valid_pong_delay4_9 = b_data_valid_pong_delay0_9 & b_data_valid_pong_delay0_13;
assign b_data_valid_pong_delay5_9 = b_data_valid_pong_delay0_9 & b_data_valid_pong_delay0_14;
assign b_data_valid_pong_delay6_9 = b_data_valid_pong_delay0_9 & b_data_valid_pong_delay0_15;
assign b_data_valid_pong_delay7_9 = b_data_valid_pong_delay0_9 & b_data_valid_pong_delay0_16;
assign b_data_valid_pong_delay8_9 = b_data_valid_pong_delay0_9 & b_data_valid_pong_delay0_17;
assign b_data_valid_pong_delay9_9 = b_data_valid_pong_delay0_9 & b_data_valid_pong_delay0_18;
assign b_data_valid_pong_delay10_9 = b_data_valid_pong_delay0_9 & b_data_valid_pong_delay0_19;
assign b_data_valid_pong_delay11_9 = b_data_valid_pong_delay0_9 & b_data_valid_pong_delay0_20;
assign b_data_valid_pong_delay12_9 = b_data_valid_pong_delay0_9 & b_data_valid_pong_delay0_21;
assign b_data_valid_pong_delay13_9 = b_data_valid_pong_delay0_9 & b_data_valid_pong_delay0_22;
assign b_data_valid_pong_delay14_9 = b_data_valid_pong_delay0_9 & b_data_valid_pong_delay0_23;
assign b_data_valid_pong_delay15_9 = b_data_valid_pong_delay0_9 & b_data_valid_pong_delay0_24;
assign b_data_valid_pong_delay1_10 = b_data_valid_pong_delay0_10 & b_data_valid_pong_delay0_11;
assign b_data_valid_pong_delay2_10 = b_data_valid_pong_delay0_10 & b_data_valid_pong_delay0_12;
assign b_data_valid_pong_delay3_10 = b_data_valid_pong_delay0_10 & b_data_valid_pong_delay0_13;
assign b_data_valid_pong_delay4_10 = b_data_valid_pong_delay0_10 & b_data_valid_pong_delay0_14;
assign b_data_valid_pong_delay5_10 = b_data_valid_pong_delay0_10 & b_data_valid_pong_delay0_15;
assign b_data_valid_pong_delay6_10 = b_data_valid_pong_delay0_10 & b_data_valid_pong_delay0_16;
assign b_data_valid_pong_delay7_10 = b_data_valid_pong_delay0_10 & b_data_valid_pong_delay0_17;
assign b_data_valid_pong_delay8_10 = b_data_valid_pong_delay0_10 & b_data_valid_pong_delay0_18;
assign b_data_valid_pong_delay9_10 = b_data_valid_pong_delay0_10 & b_data_valid_pong_delay0_19;
assign b_data_valid_pong_delay10_10 = b_data_valid_pong_delay0_10 & b_data_valid_pong_delay0_20;
assign b_data_valid_pong_delay11_10 = b_data_valid_pong_delay0_10 & b_data_valid_pong_delay0_21;
assign b_data_valid_pong_delay12_10 = b_data_valid_pong_delay0_10 & b_data_valid_pong_delay0_22;
assign b_data_valid_pong_delay13_10 = b_data_valid_pong_delay0_10 & b_data_valid_pong_delay0_23;
assign b_data_valid_pong_delay14_10 = b_data_valid_pong_delay0_10 & b_data_valid_pong_delay0_24;
assign b_data_valid_pong_delay15_10 = b_data_valid_pong_delay0_10 & b_data_valid_pong_delay0_25;
assign b_data_valid_pong_delay1_11 = b_data_valid_pong_delay0_11 & b_data_valid_pong_delay0_12;
assign b_data_valid_pong_delay2_11 = b_data_valid_pong_delay0_11 & b_data_valid_pong_delay0_13;
assign b_data_valid_pong_delay3_11 = b_data_valid_pong_delay0_11 & b_data_valid_pong_delay0_14;
assign b_data_valid_pong_delay4_11 = b_data_valid_pong_delay0_11 & b_data_valid_pong_delay0_15;
assign b_data_valid_pong_delay5_11 = b_data_valid_pong_delay0_11 & b_data_valid_pong_delay0_16;
assign b_data_valid_pong_delay6_11 = b_data_valid_pong_delay0_11 & b_data_valid_pong_delay0_17;
assign b_data_valid_pong_delay7_11 = b_data_valid_pong_delay0_11 & b_data_valid_pong_delay0_18;
assign b_data_valid_pong_delay8_11 = b_data_valid_pong_delay0_11 & b_data_valid_pong_delay0_19;
assign b_data_valid_pong_delay9_11 = b_data_valid_pong_delay0_11 & b_data_valid_pong_delay0_20;
assign b_data_valid_pong_delay10_11 = b_data_valid_pong_delay0_11 & b_data_valid_pong_delay0_21;
assign b_data_valid_pong_delay11_11 = b_data_valid_pong_delay0_11 & b_data_valid_pong_delay0_22;
assign b_data_valid_pong_delay12_11 = b_data_valid_pong_delay0_11 & b_data_valid_pong_delay0_23;
assign b_data_valid_pong_delay13_11 = b_data_valid_pong_delay0_11 & b_data_valid_pong_delay0_24;
assign b_data_valid_pong_delay14_11 = b_data_valid_pong_delay0_11 & b_data_valid_pong_delay0_25;
assign b_data_valid_pong_delay15_11 = b_data_valid_pong_delay0_11 & b_data_valid_pong_delay0_26;
assign b_data_valid_pong_delay1_12 = b_data_valid_pong_delay0_12 & b_data_valid_pong_delay0_13;
assign b_data_valid_pong_delay2_12 = b_data_valid_pong_delay0_12 & b_data_valid_pong_delay0_14;
assign b_data_valid_pong_delay3_12 = b_data_valid_pong_delay0_12 & b_data_valid_pong_delay0_15;
assign b_data_valid_pong_delay4_12 = b_data_valid_pong_delay0_12 & b_data_valid_pong_delay0_16;
assign b_data_valid_pong_delay5_12 = b_data_valid_pong_delay0_12 & b_data_valid_pong_delay0_17;
assign b_data_valid_pong_delay6_12 = b_data_valid_pong_delay0_12 & b_data_valid_pong_delay0_18;
assign b_data_valid_pong_delay7_12 = b_data_valid_pong_delay0_12 & b_data_valid_pong_delay0_19;
assign b_data_valid_pong_delay8_12 = b_data_valid_pong_delay0_12 & b_data_valid_pong_delay0_20;
assign b_data_valid_pong_delay9_12 = b_data_valid_pong_delay0_12 & b_data_valid_pong_delay0_21;
assign b_data_valid_pong_delay10_12 = b_data_valid_pong_delay0_12 & b_data_valid_pong_delay0_22;
assign b_data_valid_pong_delay11_12 = b_data_valid_pong_delay0_12 & b_data_valid_pong_delay0_23;
assign b_data_valid_pong_delay12_12 = b_data_valid_pong_delay0_12 & b_data_valid_pong_delay0_24;
assign b_data_valid_pong_delay13_12 = b_data_valid_pong_delay0_12 & b_data_valid_pong_delay0_25;
assign b_data_valid_pong_delay14_12 = b_data_valid_pong_delay0_12 & b_data_valid_pong_delay0_26;
assign b_data_valid_pong_delay15_12 = b_data_valid_pong_delay0_12 & b_data_valid_pong_delay0_27;
assign b_data_valid_pong_delay1_13 = b_data_valid_pong_delay0_13 & b_data_valid_pong_delay0_14;
assign b_data_valid_pong_delay2_13 = b_data_valid_pong_delay0_13 & b_data_valid_pong_delay0_15;
assign b_data_valid_pong_delay3_13 = b_data_valid_pong_delay0_13 & b_data_valid_pong_delay0_16;
assign b_data_valid_pong_delay4_13 = b_data_valid_pong_delay0_13 & b_data_valid_pong_delay0_17;
assign b_data_valid_pong_delay5_13 = b_data_valid_pong_delay0_13 & b_data_valid_pong_delay0_18;
assign b_data_valid_pong_delay6_13 = b_data_valid_pong_delay0_13 & b_data_valid_pong_delay0_19;
assign b_data_valid_pong_delay7_13 = b_data_valid_pong_delay0_13 & b_data_valid_pong_delay0_20;
assign b_data_valid_pong_delay8_13 = b_data_valid_pong_delay0_13 & b_data_valid_pong_delay0_21;
assign b_data_valid_pong_delay9_13 = b_data_valid_pong_delay0_13 & b_data_valid_pong_delay0_22;
assign b_data_valid_pong_delay10_13 = b_data_valid_pong_delay0_13 & b_data_valid_pong_delay0_23;
assign b_data_valid_pong_delay11_13 = b_data_valid_pong_delay0_13 & b_data_valid_pong_delay0_24;
assign b_data_valid_pong_delay12_13 = b_data_valid_pong_delay0_13 & b_data_valid_pong_delay0_25;
assign b_data_valid_pong_delay13_13 = b_data_valid_pong_delay0_13 & b_data_valid_pong_delay0_26;
assign b_data_valid_pong_delay14_13 = b_data_valid_pong_delay0_13 & b_data_valid_pong_delay0_27;
assign b_data_valid_pong_delay15_13 = b_data_valid_pong_delay0_13 & b_data_valid_pong_delay0_28;
assign b_data_valid_pong_delay1_14 = b_data_valid_pong_delay0_14 & b_data_valid_pong_delay0_15;
assign b_data_valid_pong_delay2_14 = b_data_valid_pong_delay0_14 & b_data_valid_pong_delay0_16;
assign b_data_valid_pong_delay3_14 = b_data_valid_pong_delay0_14 & b_data_valid_pong_delay0_17;
assign b_data_valid_pong_delay4_14 = b_data_valid_pong_delay0_14 & b_data_valid_pong_delay0_18;
assign b_data_valid_pong_delay5_14 = b_data_valid_pong_delay0_14 & b_data_valid_pong_delay0_19;
assign b_data_valid_pong_delay6_14 = b_data_valid_pong_delay0_14 & b_data_valid_pong_delay0_20;
assign b_data_valid_pong_delay7_14 = b_data_valid_pong_delay0_14 & b_data_valid_pong_delay0_21;
assign b_data_valid_pong_delay8_14 = b_data_valid_pong_delay0_14 & b_data_valid_pong_delay0_22;
assign b_data_valid_pong_delay9_14 = b_data_valid_pong_delay0_14 & b_data_valid_pong_delay0_23;
assign b_data_valid_pong_delay10_14 = b_data_valid_pong_delay0_14 & b_data_valid_pong_delay0_24;
assign b_data_valid_pong_delay11_14 = b_data_valid_pong_delay0_14 & b_data_valid_pong_delay0_25;
assign b_data_valid_pong_delay12_14 = b_data_valid_pong_delay0_14 & b_data_valid_pong_delay0_26;
assign b_data_valid_pong_delay13_14 = b_data_valid_pong_delay0_14 & b_data_valid_pong_delay0_27;
assign b_data_valid_pong_delay14_14 = b_data_valid_pong_delay0_14 & b_data_valid_pong_delay0_28;
assign b_data_valid_pong_delay15_14 = b_data_valid_pong_delay0_14 & b_data_valid_pong_delay0_29;
assign b_data_valid_pong_delay1_15 = b_data_valid_pong_delay0_15 & b_data_valid_pong_delay0_16;
assign b_data_valid_pong_delay2_15 = b_data_valid_pong_delay0_15 & b_data_valid_pong_delay0_17;
assign b_data_valid_pong_delay3_15 = b_data_valid_pong_delay0_15 & b_data_valid_pong_delay0_18;
assign b_data_valid_pong_delay4_15 = b_data_valid_pong_delay0_15 & b_data_valid_pong_delay0_19;
assign b_data_valid_pong_delay5_15 = b_data_valid_pong_delay0_15 & b_data_valid_pong_delay0_20;
assign b_data_valid_pong_delay6_15 = b_data_valid_pong_delay0_15 & b_data_valid_pong_delay0_21;
assign b_data_valid_pong_delay7_15 = b_data_valid_pong_delay0_15 & b_data_valid_pong_delay0_22;
assign b_data_valid_pong_delay8_15 = b_data_valid_pong_delay0_15 & b_data_valid_pong_delay0_23;
assign b_data_valid_pong_delay9_15 = b_data_valid_pong_delay0_15 & b_data_valid_pong_delay0_24;
assign b_data_valid_pong_delay10_15 = b_data_valid_pong_delay0_15 & b_data_valid_pong_delay0_25;
assign b_data_valid_pong_delay11_15 = b_data_valid_pong_delay0_15 & b_data_valid_pong_delay0_26;
assign b_data_valid_pong_delay12_15 = b_data_valid_pong_delay0_15 & b_data_valid_pong_delay0_27;
assign b_data_valid_pong_delay13_15 = b_data_valid_pong_delay0_15 & b_data_valid_pong_delay0_28;
assign b_data_valid_pong_delay14_15 = b_data_valid_pong_delay0_15 & b_data_valid_pong_delay0_29;
assign b_data_valid_pong_delay15_15 = b_data_valid_pong_delay0_15 & b_data_valid_pong_delay0_30;

// Signals for Each PING buffer

reg b_data_valid_ping_delay0_1;
reg b_data_valid_ping_delay0_2;
reg b_data_valid_ping_delay0_3;
reg b_data_valid_ping_delay0_4;
reg b_data_valid_ping_delay0_5;
reg b_data_valid_ping_delay0_6;
reg b_data_valid_ping_delay0_7;
reg b_data_valid_ping_delay0_8;
reg b_data_valid_ping_delay0_9;
reg b_data_valid_ping_delay0_10;
reg b_data_valid_ping_delay0_11;
reg b_data_valid_ping_delay0_12;
reg b_data_valid_ping_delay0_13;
reg b_data_valid_ping_delay0_14;
reg b_data_valid_ping_delay0_15;
reg b_data_valid_ping_delay0_16;
reg b_data_valid_ping_delay0_17;
reg b_data_valid_ping_delay0_18;
reg b_data_valid_ping_delay0_19;
reg b_data_valid_ping_delay0_20;
reg b_data_valid_ping_delay0_21;
reg b_data_valid_ping_delay0_22;
reg b_data_valid_ping_delay0_23;
reg b_data_valid_ping_delay0_24;
reg b_data_valid_ping_delay0_25;
reg b_data_valid_ping_delay0_26;
reg b_data_valid_ping_delay0_27;
reg b_data_valid_ping_delay0_28;
reg b_data_valid_ping_delay0_29;
reg b_data_valid_ping_delay0_30;
wire b_data_valid_ping_delay1_0;
wire b_data_valid_ping_delay2_0;
wire b_data_valid_ping_delay3_0;
wire b_data_valid_ping_delay4_0;
wire b_data_valid_ping_delay5_0;
wire b_data_valid_ping_delay6_0;
wire b_data_valid_ping_delay7_0;
wire b_data_valid_ping_delay8_0;
wire b_data_valid_ping_delay9_0;
wire b_data_valid_ping_delay10_0;
wire b_data_valid_ping_delay11_0;
wire b_data_valid_ping_delay12_0;
wire b_data_valid_ping_delay13_0;
wire b_data_valid_ping_delay14_0;
wire b_data_valid_ping_delay15_0;
wire b_data_valid_ping_delay1_1;
wire b_data_valid_ping_delay2_1;
wire b_data_valid_ping_delay3_1;
wire b_data_valid_ping_delay4_1;
wire b_data_valid_ping_delay5_1;
wire b_data_valid_ping_delay6_1;
wire b_data_valid_ping_delay7_1;
wire b_data_valid_ping_delay8_1;
wire b_data_valid_ping_delay9_1;
wire b_data_valid_ping_delay10_1;
wire b_data_valid_ping_delay11_1;
wire b_data_valid_ping_delay12_1;
wire b_data_valid_ping_delay13_1;
wire b_data_valid_ping_delay14_1;
wire b_data_valid_ping_delay15_1;
wire b_data_valid_ping_delay1_2;
wire b_data_valid_ping_delay2_2;
wire b_data_valid_ping_delay3_2;
wire b_data_valid_ping_delay4_2;
wire b_data_valid_ping_delay5_2;
wire b_data_valid_ping_delay6_2;
wire b_data_valid_ping_delay7_2;
wire b_data_valid_ping_delay8_2;
wire b_data_valid_ping_delay9_2;
wire b_data_valid_ping_delay10_2;
wire b_data_valid_ping_delay11_2;
wire b_data_valid_ping_delay12_2;
wire b_data_valid_ping_delay13_2;
wire b_data_valid_ping_delay14_2;
wire b_data_valid_ping_delay15_2;
wire b_data_valid_ping_delay1_3;
wire b_data_valid_ping_delay2_3;
wire b_data_valid_ping_delay3_3;
wire b_data_valid_ping_delay4_3;
wire b_data_valid_ping_delay5_3;
wire b_data_valid_ping_delay6_3;
wire b_data_valid_ping_delay7_3;
wire b_data_valid_ping_delay8_3;
wire b_data_valid_ping_delay9_3;
wire b_data_valid_ping_delay10_3;
wire b_data_valid_ping_delay11_3;
wire b_data_valid_ping_delay12_3;
wire b_data_valid_ping_delay13_3;
wire b_data_valid_ping_delay14_3;
wire b_data_valid_ping_delay15_3;
wire b_data_valid_ping_delay1_4;
wire b_data_valid_ping_delay2_4;
wire b_data_valid_ping_delay3_4;
wire b_data_valid_ping_delay4_4;
wire b_data_valid_ping_delay5_4;
wire b_data_valid_ping_delay6_4;
wire b_data_valid_ping_delay7_4;
wire b_data_valid_ping_delay8_4;
wire b_data_valid_ping_delay9_4;
wire b_data_valid_ping_delay10_4;
wire b_data_valid_ping_delay11_4;
wire b_data_valid_ping_delay12_4;
wire b_data_valid_ping_delay13_4;
wire b_data_valid_ping_delay14_4;
wire b_data_valid_ping_delay15_4;
wire b_data_valid_ping_delay1_5;
wire b_data_valid_ping_delay2_5;
wire b_data_valid_ping_delay3_5;
wire b_data_valid_ping_delay4_5;
wire b_data_valid_ping_delay5_5;
wire b_data_valid_ping_delay6_5;
wire b_data_valid_ping_delay7_5;
wire b_data_valid_ping_delay8_5;
wire b_data_valid_ping_delay9_5;
wire b_data_valid_ping_delay10_5;
wire b_data_valid_ping_delay11_5;
wire b_data_valid_ping_delay12_5;
wire b_data_valid_ping_delay13_5;
wire b_data_valid_ping_delay14_5;
wire b_data_valid_ping_delay15_5;
wire b_data_valid_ping_delay1_6;
wire b_data_valid_ping_delay2_6;
wire b_data_valid_ping_delay3_6;
wire b_data_valid_ping_delay4_6;
wire b_data_valid_ping_delay5_6;
wire b_data_valid_ping_delay6_6;
wire b_data_valid_ping_delay7_6;
wire b_data_valid_ping_delay8_6;
wire b_data_valid_ping_delay9_6;
wire b_data_valid_ping_delay10_6;
wire b_data_valid_ping_delay11_6;
wire b_data_valid_ping_delay12_6;
wire b_data_valid_ping_delay13_6;
wire b_data_valid_ping_delay14_6;
wire b_data_valid_ping_delay15_6;
wire b_data_valid_ping_delay1_7;
wire b_data_valid_ping_delay2_7;
wire b_data_valid_ping_delay3_7;
wire b_data_valid_ping_delay4_7;
wire b_data_valid_ping_delay5_7;
wire b_data_valid_ping_delay6_7;
wire b_data_valid_ping_delay7_7;
wire b_data_valid_ping_delay8_7;
wire b_data_valid_ping_delay9_7;
wire b_data_valid_ping_delay10_7;
wire b_data_valid_ping_delay11_7;
wire b_data_valid_ping_delay12_7;
wire b_data_valid_ping_delay13_7;
wire b_data_valid_ping_delay14_7;
wire b_data_valid_ping_delay15_7;
wire b_data_valid_ping_delay1_8;
wire b_data_valid_ping_delay2_8;
wire b_data_valid_ping_delay3_8;
wire b_data_valid_ping_delay4_8;
wire b_data_valid_ping_delay5_8;
wire b_data_valid_ping_delay6_8;
wire b_data_valid_ping_delay7_8;
wire b_data_valid_ping_delay8_8;
wire b_data_valid_ping_delay9_8;
wire b_data_valid_ping_delay10_8;
wire b_data_valid_ping_delay11_8;
wire b_data_valid_ping_delay12_8;
wire b_data_valid_ping_delay13_8;
wire b_data_valid_ping_delay14_8;
wire b_data_valid_ping_delay15_8;
wire b_data_valid_ping_delay1_9;
wire b_data_valid_ping_delay2_9;
wire b_data_valid_ping_delay3_9;
wire b_data_valid_ping_delay4_9;
wire b_data_valid_ping_delay5_9;
wire b_data_valid_ping_delay6_9;
wire b_data_valid_ping_delay7_9;
wire b_data_valid_ping_delay8_9;
wire b_data_valid_ping_delay9_9;
wire b_data_valid_ping_delay10_9;
wire b_data_valid_ping_delay11_9;
wire b_data_valid_ping_delay12_9;
wire b_data_valid_ping_delay13_9;
wire b_data_valid_ping_delay14_9;
wire b_data_valid_ping_delay15_9;
wire b_data_valid_ping_delay1_10;
wire b_data_valid_ping_delay2_10;
wire b_data_valid_ping_delay3_10;
wire b_data_valid_ping_delay4_10;
wire b_data_valid_ping_delay5_10;
wire b_data_valid_ping_delay6_10;
wire b_data_valid_ping_delay7_10;
wire b_data_valid_ping_delay8_10;
wire b_data_valid_ping_delay9_10;
wire b_data_valid_ping_delay10_10;
wire b_data_valid_ping_delay11_10;
wire b_data_valid_ping_delay12_10;
wire b_data_valid_ping_delay13_10;
wire b_data_valid_ping_delay14_10;
wire b_data_valid_ping_delay15_10;
wire b_data_valid_ping_delay1_11;
wire b_data_valid_ping_delay2_11;
wire b_data_valid_ping_delay3_11;
wire b_data_valid_ping_delay4_11;
wire b_data_valid_ping_delay5_11;
wire b_data_valid_ping_delay6_11;
wire b_data_valid_ping_delay7_11;
wire b_data_valid_ping_delay8_11;
wire b_data_valid_ping_delay9_11;
wire b_data_valid_ping_delay10_11;
wire b_data_valid_ping_delay11_11;
wire b_data_valid_ping_delay12_11;
wire b_data_valid_ping_delay13_11;
wire b_data_valid_ping_delay14_11;
wire b_data_valid_ping_delay15_11;
wire b_data_valid_ping_delay1_12;
wire b_data_valid_ping_delay2_12;
wire b_data_valid_ping_delay3_12;
wire b_data_valid_ping_delay4_12;
wire b_data_valid_ping_delay5_12;
wire b_data_valid_ping_delay6_12;
wire b_data_valid_ping_delay7_12;
wire b_data_valid_ping_delay8_12;
wire b_data_valid_ping_delay9_12;
wire b_data_valid_ping_delay10_12;
wire b_data_valid_ping_delay11_12;
wire b_data_valid_ping_delay12_12;
wire b_data_valid_ping_delay13_12;
wire b_data_valid_ping_delay14_12;
wire b_data_valid_ping_delay15_12;
wire b_data_valid_ping_delay1_13;
wire b_data_valid_ping_delay2_13;
wire b_data_valid_ping_delay3_13;
wire b_data_valid_ping_delay4_13;
wire b_data_valid_ping_delay5_13;
wire b_data_valid_ping_delay6_13;
wire b_data_valid_ping_delay7_13;
wire b_data_valid_ping_delay8_13;
wire b_data_valid_ping_delay9_13;
wire b_data_valid_ping_delay10_13;
wire b_data_valid_ping_delay11_13;
wire b_data_valid_ping_delay12_13;
wire b_data_valid_ping_delay13_13;
wire b_data_valid_ping_delay14_13;
wire b_data_valid_ping_delay15_13;
wire b_data_valid_ping_delay1_14;
wire b_data_valid_ping_delay2_14;
wire b_data_valid_ping_delay3_14;
wire b_data_valid_ping_delay4_14;
wire b_data_valid_ping_delay5_14;
wire b_data_valid_ping_delay6_14;
wire b_data_valid_ping_delay7_14;
wire b_data_valid_ping_delay8_14;
wire b_data_valid_ping_delay9_14;
wire b_data_valid_ping_delay10_14;
wire b_data_valid_ping_delay11_14;
wire b_data_valid_ping_delay12_14;
wire b_data_valid_ping_delay13_14;
wire b_data_valid_ping_delay14_14;
wire b_data_valid_ping_delay15_14;
wire b_data_valid_ping_delay1_15;
wire b_data_valid_ping_delay2_15;
wire b_data_valid_ping_delay3_15;
wire b_data_valid_ping_delay4_15;
wire b_data_valid_ping_delay5_15;
wire b_data_valid_ping_delay6_15;
wire b_data_valid_ping_delay7_15;
wire b_data_valid_ping_delay8_15;
wire b_data_valid_ping_delay9_15;
wire b_data_valid_ping_delay10_15;
wire b_data_valid_ping_delay11_15;
wire b_data_valid_ping_delay12_15;
wire b_data_valid_ping_delay13_15;
wire b_data_valid_ping_delay14_15;
wire b_data_valid_ping_delay15_15;
  
always @ (posedge clk) begin
    b_data_valid_ping_delay0_1 <= b_data_valid_ping;
    b_data_valid_ping_delay0_2 <= b_data_valid_ping_delay0_1;
    b_data_valid_ping_delay0_3 <= b_data_valid_ping_delay0_2;
    b_data_valid_ping_delay0_4 <= b_data_valid_ping_delay0_3;
    b_data_valid_ping_delay0_5 <= b_data_valid_ping_delay0_4;
    b_data_valid_ping_delay0_6 <= b_data_valid_ping_delay0_5;
    b_data_valid_ping_delay0_7 <= b_data_valid_ping_delay0_6;
    b_data_valid_ping_delay0_8 <= b_data_valid_ping_delay0_7;
    b_data_valid_ping_delay0_9 <= b_data_valid_ping_delay0_8;
    b_data_valid_ping_delay0_10 <= b_data_valid_ping_delay0_9;
    b_data_valid_ping_delay0_11 <= b_data_valid_ping_delay0_10;
    b_data_valid_ping_delay0_12 <= b_data_valid_ping_delay0_11;
    b_data_valid_ping_delay0_13 <= b_data_valid_ping_delay0_12;
    b_data_valid_ping_delay0_14 <= b_data_valid_ping_delay0_13;
    b_data_valid_ping_delay0_15 <= b_data_valid_ping_delay0_14;
    b_data_valid_ping_delay0_16 <= b_data_valid_ping_delay0_15;
    b_data_valid_ping_delay0_17 <= b_data_valid_ping_delay0_16;
    b_data_valid_ping_delay0_18 <= b_data_valid_ping_delay0_17;
    b_data_valid_ping_delay0_19 <= b_data_valid_ping_delay0_18;
    b_data_valid_ping_delay0_20 <= b_data_valid_ping_delay0_19;
    b_data_valid_ping_delay0_21 <= b_data_valid_ping_delay0_20;
    b_data_valid_ping_delay0_22 <= b_data_valid_ping_delay0_21;
    b_data_valid_ping_delay0_23 <= b_data_valid_ping_delay0_22;
    b_data_valid_ping_delay0_24 <= b_data_valid_ping_delay0_23;
    b_data_valid_ping_delay0_25 <= b_data_valid_ping_delay0_24;
    b_data_valid_ping_delay0_26 <= b_data_valid_ping_delay0_25;
    b_data_valid_ping_delay0_27 <= b_data_valid_ping_delay0_26;
    b_data_valid_ping_delay0_28 <= b_data_valid_ping_delay0_27;
    b_data_valid_ping_delay0_29 <= b_data_valid_ping_delay0_28;
    b_data_valid_ping_delay0_30 <= b_data_valid_ping_delay0_29;
end

assign b_data_valid_ping_delay1_0 = b_data_valid_ping & b_data_valid_ping_delay0_1;
assign b_data_valid_ping_delay2_0 = b_data_valid_ping & b_data_valid_ping_delay0_2;
assign b_data_valid_ping_delay3_0 = b_data_valid_ping & b_data_valid_ping_delay0_3;
assign b_data_valid_ping_delay4_0 = b_data_valid_ping & b_data_valid_ping_delay0_4;
assign b_data_valid_ping_delay5_0 = b_data_valid_ping & b_data_valid_ping_delay0_5;
assign b_data_valid_ping_delay6_0 = b_data_valid_ping & b_data_valid_ping_delay0_6;
assign b_data_valid_ping_delay7_0 = b_data_valid_ping & b_data_valid_ping_delay0_7;
assign b_data_valid_ping_delay8_0 = b_data_valid_ping & b_data_valid_ping_delay0_8;
assign b_data_valid_ping_delay9_0 = b_data_valid_ping & b_data_valid_ping_delay0_9;
assign b_data_valid_ping_delay10_0 = b_data_valid_ping & b_data_valid_ping_delay0_10;
assign b_data_valid_ping_delay11_0 = b_data_valid_ping & b_data_valid_ping_delay0_11;
assign b_data_valid_ping_delay12_0 = b_data_valid_ping & b_data_valid_ping_delay0_12;
assign b_data_valid_ping_delay13_0 = b_data_valid_ping & b_data_valid_ping_delay0_13;
assign b_data_valid_ping_delay14_0 = b_data_valid_ping & b_data_valid_ping_delay0_14;
assign b_data_valid_ping_delay15_0 = b_data_valid_ping & b_data_valid_ping_delay0_15;
assign b_data_valid_ping_delay1_1 = b_data_valid_ping_delay0_1 & b_data_valid_ping_delay0_2;
assign b_data_valid_ping_delay2_1 = b_data_valid_ping_delay0_1 & b_data_valid_ping_delay0_3;
assign b_data_valid_ping_delay3_1 = b_data_valid_ping_delay0_1 & b_data_valid_ping_delay0_4;
assign b_data_valid_ping_delay4_1 = b_data_valid_ping_delay0_1 & b_data_valid_ping_delay0_5;
assign b_data_valid_ping_delay5_1 = b_data_valid_ping_delay0_1 & b_data_valid_ping_delay0_6;
assign b_data_valid_ping_delay6_1 = b_data_valid_ping_delay0_1 & b_data_valid_ping_delay0_7;
assign b_data_valid_ping_delay7_1 = b_data_valid_ping_delay0_1 & b_data_valid_ping_delay0_8;
assign b_data_valid_ping_delay8_1 = b_data_valid_ping_delay0_1 & b_data_valid_ping_delay0_9;
assign b_data_valid_ping_delay9_1 = b_data_valid_ping_delay0_1 & b_data_valid_ping_delay0_10;
assign b_data_valid_ping_delay10_1 = b_data_valid_ping_delay0_1 & b_data_valid_ping_delay0_11;
assign b_data_valid_ping_delay11_1 = b_data_valid_ping_delay0_1 & b_data_valid_ping_delay0_12;
assign b_data_valid_ping_delay12_1 = b_data_valid_ping_delay0_1 & b_data_valid_ping_delay0_13;
assign b_data_valid_ping_delay13_1 = b_data_valid_ping_delay0_1 & b_data_valid_ping_delay0_14;
assign b_data_valid_ping_delay14_1 = b_data_valid_ping_delay0_1 & b_data_valid_ping_delay0_15;
assign b_data_valid_ping_delay15_1 = b_data_valid_ping_delay0_1 & b_data_valid_ping_delay0_16;
assign b_data_valid_ping_delay1_2 = b_data_valid_ping_delay0_2 & b_data_valid_ping_delay0_3;
assign b_data_valid_ping_delay2_2 = b_data_valid_ping_delay0_2 & b_data_valid_ping_delay0_4;
assign b_data_valid_ping_delay3_2 = b_data_valid_ping_delay0_2 & b_data_valid_ping_delay0_5;
assign b_data_valid_ping_delay4_2 = b_data_valid_ping_delay0_2 & b_data_valid_ping_delay0_6;
assign b_data_valid_ping_delay5_2 = b_data_valid_ping_delay0_2 & b_data_valid_ping_delay0_7;
assign b_data_valid_ping_delay6_2 = b_data_valid_ping_delay0_2 & b_data_valid_ping_delay0_8;
assign b_data_valid_ping_delay7_2 = b_data_valid_ping_delay0_2 & b_data_valid_ping_delay0_9;
assign b_data_valid_ping_delay8_2 = b_data_valid_ping_delay0_2 & b_data_valid_ping_delay0_10;
assign b_data_valid_ping_delay9_2 = b_data_valid_ping_delay0_2 & b_data_valid_ping_delay0_11;
assign b_data_valid_ping_delay10_2 = b_data_valid_ping_delay0_2 & b_data_valid_ping_delay0_12;
assign b_data_valid_ping_delay11_2 = b_data_valid_ping_delay0_2 & b_data_valid_ping_delay0_13;
assign b_data_valid_ping_delay12_2 = b_data_valid_ping_delay0_2 & b_data_valid_ping_delay0_14;
assign b_data_valid_ping_delay13_2 = b_data_valid_ping_delay0_2 & b_data_valid_ping_delay0_15;
assign b_data_valid_ping_delay14_2 = b_data_valid_ping_delay0_2 & b_data_valid_ping_delay0_16;
assign b_data_valid_ping_delay15_2 = b_data_valid_ping_delay0_2 & b_data_valid_ping_delay0_17;
assign b_data_valid_ping_delay1_3 = b_data_valid_ping_delay0_3 & b_data_valid_ping_delay0_4;
assign b_data_valid_ping_delay2_3 = b_data_valid_ping_delay0_3 & b_data_valid_ping_delay0_5;
assign b_data_valid_ping_delay3_3 = b_data_valid_ping_delay0_3 & b_data_valid_ping_delay0_6;
assign b_data_valid_ping_delay4_3 = b_data_valid_ping_delay0_3 & b_data_valid_ping_delay0_7;
assign b_data_valid_ping_delay5_3 = b_data_valid_ping_delay0_3 & b_data_valid_ping_delay0_8;
assign b_data_valid_ping_delay6_3 = b_data_valid_ping_delay0_3 & b_data_valid_ping_delay0_9;
assign b_data_valid_ping_delay7_3 = b_data_valid_ping_delay0_3 & b_data_valid_ping_delay0_10;
assign b_data_valid_ping_delay8_3 = b_data_valid_ping_delay0_3 & b_data_valid_ping_delay0_11;
assign b_data_valid_ping_delay9_3 = b_data_valid_ping_delay0_3 & b_data_valid_ping_delay0_12;
assign b_data_valid_ping_delay10_3 = b_data_valid_ping_delay0_3 & b_data_valid_ping_delay0_13;
assign b_data_valid_ping_delay11_3 = b_data_valid_ping_delay0_3 & b_data_valid_ping_delay0_14;
assign b_data_valid_ping_delay12_3 = b_data_valid_ping_delay0_3 & b_data_valid_ping_delay0_15;
assign b_data_valid_ping_delay13_3 = b_data_valid_ping_delay0_3 & b_data_valid_ping_delay0_16;
assign b_data_valid_ping_delay14_3 = b_data_valid_ping_delay0_3 & b_data_valid_ping_delay0_17;
assign b_data_valid_ping_delay15_3 = b_data_valid_ping_delay0_3 & b_data_valid_ping_delay0_18;
assign b_data_valid_ping_delay1_4 = b_data_valid_ping_delay0_4 & b_data_valid_ping_delay0_5;
assign b_data_valid_ping_delay2_4 = b_data_valid_ping_delay0_4 & b_data_valid_ping_delay0_6;
assign b_data_valid_ping_delay3_4 = b_data_valid_ping_delay0_4 & b_data_valid_ping_delay0_7;
assign b_data_valid_ping_delay4_4 = b_data_valid_ping_delay0_4 & b_data_valid_ping_delay0_8;
assign b_data_valid_ping_delay5_4 = b_data_valid_ping_delay0_4 & b_data_valid_ping_delay0_9;
assign b_data_valid_ping_delay6_4 = b_data_valid_ping_delay0_4 & b_data_valid_ping_delay0_10;
assign b_data_valid_ping_delay7_4 = b_data_valid_ping_delay0_4 & b_data_valid_ping_delay0_11;
assign b_data_valid_ping_delay8_4 = b_data_valid_ping_delay0_4 & b_data_valid_ping_delay0_12;
assign b_data_valid_ping_delay9_4 = b_data_valid_ping_delay0_4 & b_data_valid_ping_delay0_13;
assign b_data_valid_ping_delay10_4 = b_data_valid_ping_delay0_4 & b_data_valid_ping_delay0_14;
assign b_data_valid_ping_delay11_4 = b_data_valid_ping_delay0_4 & b_data_valid_ping_delay0_15;
assign b_data_valid_ping_delay12_4 = b_data_valid_ping_delay0_4 & b_data_valid_ping_delay0_16;
assign b_data_valid_ping_delay13_4 = b_data_valid_ping_delay0_4 & b_data_valid_ping_delay0_17;
assign b_data_valid_ping_delay14_4 = b_data_valid_ping_delay0_4 & b_data_valid_ping_delay0_18;
assign b_data_valid_ping_delay15_4 = b_data_valid_ping_delay0_4 & b_data_valid_ping_delay0_19;
assign b_data_valid_ping_delay1_5 = b_data_valid_ping_delay0_5 & b_data_valid_ping_delay0_6;
assign b_data_valid_ping_delay2_5 = b_data_valid_ping_delay0_5 & b_data_valid_ping_delay0_7;
assign b_data_valid_ping_delay3_5 = b_data_valid_ping_delay0_5 & b_data_valid_ping_delay0_8;
assign b_data_valid_ping_delay4_5 = b_data_valid_ping_delay0_5 & b_data_valid_ping_delay0_9;
assign b_data_valid_ping_delay5_5 = b_data_valid_ping_delay0_5 & b_data_valid_ping_delay0_10;
assign b_data_valid_ping_delay6_5 = b_data_valid_ping_delay0_5 & b_data_valid_ping_delay0_11;
assign b_data_valid_ping_delay7_5 = b_data_valid_ping_delay0_5 & b_data_valid_ping_delay0_12;
assign b_data_valid_ping_delay8_5 = b_data_valid_ping_delay0_5 & b_data_valid_ping_delay0_13;
assign b_data_valid_ping_delay9_5 = b_data_valid_ping_delay0_5 & b_data_valid_ping_delay0_14;
assign b_data_valid_ping_delay10_5 = b_data_valid_ping_delay0_5 & b_data_valid_ping_delay0_15;
assign b_data_valid_ping_delay11_5 = b_data_valid_ping_delay0_5 & b_data_valid_ping_delay0_16;
assign b_data_valid_ping_delay12_5 = b_data_valid_ping_delay0_5 & b_data_valid_ping_delay0_17;
assign b_data_valid_ping_delay13_5 = b_data_valid_ping_delay0_5 & b_data_valid_ping_delay0_18;
assign b_data_valid_ping_delay14_5 = b_data_valid_ping_delay0_5 & b_data_valid_ping_delay0_19;
assign b_data_valid_ping_delay15_5 = b_data_valid_ping_delay0_5 & b_data_valid_ping_delay0_20;
assign b_data_valid_ping_delay1_6 = b_data_valid_ping_delay0_6 & b_data_valid_ping_delay0_7;
assign b_data_valid_ping_delay2_6 = b_data_valid_ping_delay0_6 & b_data_valid_ping_delay0_8;
assign b_data_valid_ping_delay3_6 = b_data_valid_ping_delay0_6 & b_data_valid_ping_delay0_9;
assign b_data_valid_ping_delay4_6 = b_data_valid_ping_delay0_6 & b_data_valid_ping_delay0_10;
assign b_data_valid_ping_delay5_6 = b_data_valid_ping_delay0_6 & b_data_valid_ping_delay0_11;
assign b_data_valid_ping_delay6_6 = b_data_valid_ping_delay0_6 & b_data_valid_ping_delay0_12;
assign b_data_valid_ping_delay7_6 = b_data_valid_ping_delay0_6 & b_data_valid_ping_delay0_13;
assign b_data_valid_ping_delay8_6 = b_data_valid_ping_delay0_6 & b_data_valid_ping_delay0_14;
assign b_data_valid_ping_delay9_6 = b_data_valid_ping_delay0_6 & b_data_valid_ping_delay0_15;
assign b_data_valid_ping_delay10_6 = b_data_valid_ping_delay0_6 & b_data_valid_ping_delay0_16;
assign b_data_valid_ping_delay11_6 = b_data_valid_ping_delay0_6 & b_data_valid_ping_delay0_17;
assign b_data_valid_ping_delay12_6 = b_data_valid_ping_delay0_6 & b_data_valid_ping_delay0_18;
assign b_data_valid_ping_delay13_6 = b_data_valid_ping_delay0_6 & b_data_valid_ping_delay0_19;
assign b_data_valid_ping_delay14_6 = b_data_valid_ping_delay0_6 & b_data_valid_ping_delay0_20;
assign b_data_valid_ping_delay15_6 = b_data_valid_ping_delay0_6 & b_data_valid_ping_delay0_21;
assign b_data_valid_ping_delay1_7 = b_data_valid_ping_delay0_7 & b_data_valid_ping_delay0_8;
assign b_data_valid_ping_delay2_7 = b_data_valid_ping_delay0_7 & b_data_valid_ping_delay0_9;
assign b_data_valid_ping_delay3_7 = b_data_valid_ping_delay0_7 & b_data_valid_ping_delay0_10;
assign b_data_valid_ping_delay4_7 = b_data_valid_ping_delay0_7 & b_data_valid_ping_delay0_11;
assign b_data_valid_ping_delay5_7 = b_data_valid_ping_delay0_7 & b_data_valid_ping_delay0_12;
assign b_data_valid_ping_delay6_7 = b_data_valid_ping_delay0_7 & b_data_valid_ping_delay0_13;
assign b_data_valid_ping_delay7_7 = b_data_valid_ping_delay0_7 & b_data_valid_ping_delay0_14;
assign b_data_valid_ping_delay8_7 = b_data_valid_ping_delay0_7 & b_data_valid_ping_delay0_15;
assign b_data_valid_ping_delay9_7 = b_data_valid_ping_delay0_7 & b_data_valid_ping_delay0_16;
assign b_data_valid_ping_delay10_7 = b_data_valid_ping_delay0_7 & b_data_valid_ping_delay0_17;
assign b_data_valid_ping_delay11_7 = b_data_valid_ping_delay0_7 & b_data_valid_ping_delay0_18;
assign b_data_valid_ping_delay12_7 = b_data_valid_ping_delay0_7 & b_data_valid_ping_delay0_19;
assign b_data_valid_ping_delay13_7 = b_data_valid_ping_delay0_7 & b_data_valid_ping_delay0_20;
assign b_data_valid_ping_delay14_7 = b_data_valid_ping_delay0_7 & b_data_valid_ping_delay0_21;
assign b_data_valid_ping_delay15_7 = b_data_valid_ping_delay0_7 & b_data_valid_ping_delay0_22;
assign b_data_valid_ping_delay1_8 = b_data_valid_ping_delay0_8 & b_data_valid_ping_delay0_9;
assign b_data_valid_ping_delay2_8 = b_data_valid_ping_delay0_8 & b_data_valid_ping_delay0_10;
assign b_data_valid_ping_delay3_8 = b_data_valid_ping_delay0_8 & b_data_valid_ping_delay0_11;
assign b_data_valid_ping_delay4_8 = b_data_valid_ping_delay0_8 & b_data_valid_ping_delay0_12;
assign b_data_valid_ping_delay5_8 = b_data_valid_ping_delay0_8 & b_data_valid_ping_delay0_13;
assign b_data_valid_ping_delay6_8 = b_data_valid_ping_delay0_8 & b_data_valid_ping_delay0_14;
assign b_data_valid_ping_delay7_8 = b_data_valid_ping_delay0_8 & b_data_valid_ping_delay0_15;
assign b_data_valid_ping_delay8_8 = b_data_valid_ping_delay0_8 & b_data_valid_ping_delay0_16;
assign b_data_valid_ping_delay9_8 = b_data_valid_ping_delay0_8 & b_data_valid_ping_delay0_17;
assign b_data_valid_ping_delay10_8 = b_data_valid_ping_delay0_8 & b_data_valid_ping_delay0_18;
assign b_data_valid_ping_delay11_8 = b_data_valid_ping_delay0_8 & b_data_valid_ping_delay0_19;
assign b_data_valid_ping_delay12_8 = b_data_valid_ping_delay0_8 & b_data_valid_ping_delay0_20;
assign b_data_valid_ping_delay13_8 = b_data_valid_ping_delay0_8 & b_data_valid_ping_delay0_21;
assign b_data_valid_ping_delay14_8 = b_data_valid_ping_delay0_8 & b_data_valid_ping_delay0_22;
assign b_data_valid_ping_delay15_8 = b_data_valid_ping_delay0_8 & b_data_valid_ping_delay0_23;
assign b_data_valid_ping_delay1_9 = b_data_valid_ping_delay0_9 & b_data_valid_ping_delay0_10;
assign b_data_valid_ping_delay2_9 = b_data_valid_ping_delay0_9 & b_data_valid_ping_delay0_11;
assign b_data_valid_ping_delay3_9 = b_data_valid_ping_delay0_9 & b_data_valid_ping_delay0_12;
assign b_data_valid_ping_delay4_9 = b_data_valid_ping_delay0_9 & b_data_valid_ping_delay0_13;
assign b_data_valid_ping_delay5_9 = b_data_valid_ping_delay0_9 & b_data_valid_ping_delay0_14;
assign b_data_valid_ping_delay6_9 = b_data_valid_ping_delay0_9 & b_data_valid_ping_delay0_15;
assign b_data_valid_ping_delay7_9 = b_data_valid_ping_delay0_9 & b_data_valid_ping_delay0_16;
assign b_data_valid_ping_delay8_9 = b_data_valid_ping_delay0_9 & b_data_valid_ping_delay0_17;
assign b_data_valid_ping_delay9_9 = b_data_valid_ping_delay0_9 & b_data_valid_ping_delay0_18;
assign b_data_valid_ping_delay10_9 = b_data_valid_ping_delay0_9 & b_data_valid_ping_delay0_19;
assign b_data_valid_ping_delay11_9 = b_data_valid_ping_delay0_9 & b_data_valid_ping_delay0_20;
assign b_data_valid_ping_delay12_9 = b_data_valid_ping_delay0_9 & b_data_valid_ping_delay0_21;
assign b_data_valid_ping_delay13_9 = b_data_valid_ping_delay0_9 & b_data_valid_ping_delay0_22;
assign b_data_valid_ping_delay14_9 = b_data_valid_ping_delay0_9 & b_data_valid_ping_delay0_23;
assign b_data_valid_ping_delay15_9 = b_data_valid_ping_delay0_9 & b_data_valid_ping_delay0_24;
assign b_data_valid_ping_delay1_10 = b_data_valid_ping_delay0_10 & b_data_valid_ping_delay0_11;
assign b_data_valid_ping_delay2_10 = b_data_valid_ping_delay0_10 & b_data_valid_ping_delay0_12;
assign b_data_valid_ping_delay3_10 = b_data_valid_ping_delay0_10 & b_data_valid_ping_delay0_13;
assign b_data_valid_ping_delay4_10 = b_data_valid_ping_delay0_10 & b_data_valid_ping_delay0_14;
assign b_data_valid_ping_delay5_10 = b_data_valid_ping_delay0_10 & b_data_valid_ping_delay0_15;
assign b_data_valid_ping_delay6_10 = b_data_valid_ping_delay0_10 & b_data_valid_ping_delay0_16;
assign b_data_valid_ping_delay7_10 = b_data_valid_ping_delay0_10 & b_data_valid_ping_delay0_17;
assign b_data_valid_ping_delay8_10 = b_data_valid_ping_delay0_10 & b_data_valid_ping_delay0_18;
assign b_data_valid_ping_delay9_10 = b_data_valid_ping_delay0_10 & b_data_valid_ping_delay0_19;
assign b_data_valid_ping_delay10_10 = b_data_valid_ping_delay0_10 & b_data_valid_ping_delay0_20;
assign b_data_valid_ping_delay11_10 = b_data_valid_ping_delay0_10 & b_data_valid_ping_delay0_21;
assign b_data_valid_ping_delay12_10 = b_data_valid_ping_delay0_10 & b_data_valid_ping_delay0_22;
assign b_data_valid_ping_delay13_10 = b_data_valid_ping_delay0_10 & b_data_valid_ping_delay0_23;
assign b_data_valid_ping_delay14_10 = b_data_valid_ping_delay0_10 & b_data_valid_ping_delay0_24;
assign b_data_valid_ping_delay15_10 = b_data_valid_ping_delay0_10 & b_data_valid_ping_delay0_25;
assign b_data_valid_ping_delay1_11 = b_data_valid_ping_delay0_11 & b_data_valid_ping_delay0_12;
assign b_data_valid_ping_delay2_11 = b_data_valid_ping_delay0_11 & b_data_valid_ping_delay0_13;
assign b_data_valid_ping_delay3_11 = b_data_valid_ping_delay0_11 & b_data_valid_ping_delay0_14;
assign b_data_valid_ping_delay4_11 = b_data_valid_ping_delay0_11 & b_data_valid_ping_delay0_15;
assign b_data_valid_ping_delay5_11 = b_data_valid_ping_delay0_11 & b_data_valid_ping_delay0_16;
assign b_data_valid_ping_delay6_11 = b_data_valid_ping_delay0_11 & b_data_valid_ping_delay0_17;
assign b_data_valid_ping_delay7_11 = b_data_valid_ping_delay0_11 & b_data_valid_ping_delay0_18;
assign b_data_valid_ping_delay8_11 = b_data_valid_ping_delay0_11 & b_data_valid_ping_delay0_19;
assign b_data_valid_ping_delay9_11 = b_data_valid_ping_delay0_11 & b_data_valid_ping_delay0_20;
assign b_data_valid_ping_delay10_11 = b_data_valid_ping_delay0_11 & b_data_valid_ping_delay0_21;
assign b_data_valid_ping_delay11_11 = b_data_valid_ping_delay0_11 & b_data_valid_ping_delay0_22;
assign b_data_valid_ping_delay12_11 = b_data_valid_ping_delay0_11 & b_data_valid_ping_delay0_23;
assign b_data_valid_ping_delay13_11 = b_data_valid_ping_delay0_11 & b_data_valid_ping_delay0_24;
assign b_data_valid_ping_delay14_11 = b_data_valid_ping_delay0_11 & b_data_valid_ping_delay0_25;
assign b_data_valid_ping_delay15_11 = b_data_valid_ping_delay0_11 & b_data_valid_ping_delay0_26;
assign b_data_valid_ping_delay1_12 = b_data_valid_ping_delay0_12 & b_data_valid_ping_delay0_13;
assign b_data_valid_ping_delay2_12 = b_data_valid_ping_delay0_12 & b_data_valid_ping_delay0_14;
assign b_data_valid_ping_delay3_12 = b_data_valid_ping_delay0_12 & b_data_valid_ping_delay0_15;
assign b_data_valid_ping_delay4_12 = b_data_valid_ping_delay0_12 & b_data_valid_ping_delay0_16;
assign b_data_valid_ping_delay5_12 = b_data_valid_ping_delay0_12 & b_data_valid_ping_delay0_17;
assign b_data_valid_ping_delay6_12 = b_data_valid_ping_delay0_12 & b_data_valid_ping_delay0_18;
assign b_data_valid_ping_delay7_12 = b_data_valid_ping_delay0_12 & b_data_valid_ping_delay0_19;
assign b_data_valid_ping_delay8_12 = b_data_valid_ping_delay0_12 & b_data_valid_ping_delay0_20;
assign b_data_valid_ping_delay9_12 = b_data_valid_ping_delay0_12 & b_data_valid_ping_delay0_21;
assign b_data_valid_ping_delay10_12 = b_data_valid_ping_delay0_12 & b_data_valid_ping_delay0_22;
assign b_data_valid_ping_delay11_12 = b_data_valid_ping_delay0_12 & b_data_valid_ping_delay0_23;
assign b_data_valid_ping_delay12_12 = b_data_valid_ping_delay0_12 & b_data_valid_ping_delay0_24;
assign b_data_valid_ping_delay13_12 = b_data_valid_ping_delay0_12 & b_data_valid_ping_delay0_25;
assign b_data_valid_ping_delay14_12 = b_data_valid_ping_delay0_12 & b_data_valid_ping_delay0_26;
assign b_data_valid_ping_delay15_12 = b_data_valid_ping_delay0_12 & b_data_valid_ping_delay0_27;
assign b_data_valid_ping_delay1_13 = b_data_valid_ping_delay0_13 & b_data_valid_ping_delay0_14;
assign b_data_valid_ping_delay2_13 = b_data_valid_ping_delay0_13 & b_data_valid_ping_delay0_15;
assign b_data_valid_ping_delay3_13 = b_data_valid_ping_delay0_13 & b_data_valid_ping_delay0_16;
assign b_data_valid_ping_delay4_13 = b_data_valid_ping_delay0_13 & b_data_valid_ping_delay0_17;
assign b_data_valid_ping_delay5_13 = b_data_valid_ping_delay0_13 & b_data_valid_ping_delay0_18;
assign b_data_valid_ping_delay6_13 = b_data_valid_ping_delay0_13 & b_data_valid_ping_delay0_19;
assign b_data_valid_ping_delay7_13 = b_data_valid_ping_delay0_13 & b_data_valid_ping_delay0_20;
assign b_data_valid_ping_delay8_13 = b_data_valid_ping_delay0_13 & b_data_valid_ping_delay0_21;
assign b_data_valid_ping_delay9_13 = b_data_valid_ping_delay0_13 & b_data_valid_ping_delay0_22;
assign b_data_valid_ping_delay10_13 = b_data_valid_ping_delay0_13 & b_data_valid_ping_delay0_23;
assign b_data_valid_ping_delay11_13 = b_data_valid_ping_delay0_13 & b_data_valid_ping_delay0_24;
assign b_data_valid_ping_delay12_13 = b_data_valid_ping_delay0_13 & b_data_valid_ping_delay0_25;
assign b_data_valid_ping_delay13_13 = b_data_valid_ping_delay0_13 & b_data_valid_ping_delay0_26;
assign b_data_valid_ping_delay14_13 = b_data_valid_ping_delay0_13 & b_data_valid_ping_delay0_27;
assign b_data_valid_ping_delay15_13 = b_data_valid_ping_delay0_13 & b_data_valid_ping_delay0_28;
assign b_data_valid_ping_delay1_14 = b_data_valid_ping_delay0_14 & b_data_valid_ping_delay0_15;
assign b_data_valid_ping_delay2_14 = b_data_valid_ping_delay0_14 & b_data_valid_ping_delay0_16;
assign b_data_valid_ping_delay3_14 = b_data_valid_ping_delay0_14 & b_data_valid_ping_delay0_17;
assign b_data_valid_ping_delay4_14 = b_data_valid_ping_delay0_14 & b_data_valid_ping_delay0_18;
assign b_data_valid_ping_delay5_14 = b_data_valid_ping_delay0_14 & b_data_valid_ping_delay0_19;
assign b_data_valid_ping_delay6_14 = b_data_valid_ping_delay0_14 & b_data_valid_ping_delay0_20;
assign b_data_valid_ping_delay7_14 = b_data_valid_ping_delay0_14 & b_data_valid_ping_delay0_21;
assign b_data_valid_ping_delay8_14 = b_data_valid_ping_delay0_14 & b_data_valid_ping_delay0_22;
assign b_data_valid_ping_delay9_14 = b_data_valid_ping_delay0_14 & b_data_valid_ping_delay0_23;
assign b_data_valid_ping_delay10_14 = b_data_valid_ping_delay0_14 & b_data_valid_ping_delay0_24;
assign b_data_valid_ping_delay11_14 = b_data_valid_ping_delay0_14 & b_data_valid_ping_delay0_25;
assign b_data_valid_ping_delay12_14 = b_data_valid_ping_delay0_14 & b_data_valid_ping_delay0_26;
assign b_data_valid_ping_delay13_14 = b_data_valid_ping_delay0_14 & b_data_valid_ping_delay0_27;
assign b_data_valid_ping_delay14_14 = b_data_valid_ping_delay0_14 & b_data_valid_ping_delay0_28;
assign b_data_valid_ping_delay15_14 = b_data_valid_ping_delay0_14 & b_data_valid_ping_delay0_29;
assign b_data_valid_ping_delay1_15 = b_data_valid_ping_delay0_15 & b_data_valid_ping_delay0_16;
assign b_data_valid_ping_delay2_15 = b_data_valid_ping_delay0_15 & b_data_valid_ping_delay0_17;
assign b_data_valid_ping_delay3_15 = b_data_valid_ping_delay0_15 & b_data_valid_ping_delay0_18;
assign b_data_valid_ping_delay4_15 = b_data_valid_ping_delay0_15 & b_data_valid_ping_delay0_19;
assign b_data_valid_ping_delay5_15 = b_data_valid_ping_delay0_15 & b_data_valid_ping_delay0_20;
assign b_data_valid_ping_delay6_15 = b_data_valid_ping_delay0_15 & b_data_valid_ping_delay0_21;
assign b_data_valid_ping_delay7_15 = b_data_valid_ping_delay0_15 & b_data_valid_ping_delay0_22;
assign b_data_valid_ping_delay8_15 = b_data_valid_ping_delay0_15 & b_data_valid_ping_delay0_23;
assign b_data_valid_ping_delay9_15 = b_data_valid_ping_delay0_15 & b_data_valid_ping_delay0_24;
assign b_data_valid_ping_delay10_15 = b_data_valid_ping_delay0_15 & b_data_valid_ping_delay0_25;
assign b_data_valid_ping_delay11_15 = b_data_valid_ping_delay0_15 & b_data_valid_ping_delay0_26;
assign b_data_valid_ping_delay12_15 = b_data_valid_ping_delay0_15 & b_data_valid_ping_delay0_27;
assign b_data_valid_ping_delay13_15 = b_data_valid_ping_delay0_15 & b_data_valid_ping_delay0_28;
assign b_data_valid_ping_delay14_15 = b_data_valid_ping_delay0_15 & b_data_valid_ping_delay0_29;
assign b_data_valid_ping_delay15_15 = b_data_valid_ping_delay0_15 & b_data_valid_ping_delay0_30;

wire [`DWIDTH-1:0] in_a_0_0_NC, in_a_0_1_NC, in_a_0_2_NC, in_a_0_3_NC, in_a_0_4_NC, in_a_0_5_NC, in_a_0_6_NC, in_a_0_7_NC, in_a_0_8_NC, in_a_0_9_NC, in_a_0_10_NC, in_a_0_11_NC, in_a_0_12_NC, in_a_0_13_NC, in_a_0_14_NC, in_a_0_15_NC, in_a_1_0_NC, in_a_1_1_NC, in_a_1_2_NC, in_a_1_3_NC, in_a_1_4_NC, in_a_1_5_NC, in_a_1_6_NC, in_a_1_7_NC, in_a_1_8_NC, in_a_1_9_NC, in_a_1_10_NC, in_a_1_11_NC, in_a_1_12_NC, in_a_1_13_NC, in_a_1_14_NC, in_a_1_15_NC, in_a_2_0_NC, in_a_2_1_NC, in_a_2_2_NC, in_a_2_3_NC, in_a_2_4_NC, in_a_2_5_NC, in_a_2_6_NC, in_a_2_7_NC, in_a_2_8_NC, in_a_2_9_NC, in_a_2_10_NC, in_a_2_11_NC, in_a_2_12_NC, in_a_2_13_NC, in_a_2_14_NC, in_a_2_15_NC, in_a_3_0_NC, in_a_3_1_NC, in_a_3_2_NC, in_a_3_3_NC, in_a_3_4_NC, in_a_3_5_NC, in_a_3_6_NC, in_a_3_7_NC, in_a_3_8_NC, in_a_3_9_NC, in_a_3_10_NC, in_a_3_11_NC, in_a_3_12_NC, in_a_3_13_NC, in_a_3_14_NC, in_a_3_15_NC, in_a_4_0_NC, in_a_4_1_NC, in_a_4_2_NC, in_a_4_3_NC, in_a_4_4_NC, in_a_4_5_NC, in_a_4_6_NC, in_a_4_7_NC, in_a_4_8_NC, in_a_4_9_NC, in_a_4_10_NC, in_a_4_11_NC, in_a_4_12_NC, in_a_4_13_NC, in_a_4_14_NC, in_a_4_15_NC, in_a_5_0_NC, in_a_5_1_NC, in_a_5_2_NC, in_a_5_3_NC, in_a_5_4_NC, in_a_5_5_NC, in_a_5_6_NC, in_a_5_7_NC, in_a_5_8_NC, in_a_5_9_NC, in_a_5_10_NC, in_a_5_11_NC, in_a_5_12_NC, in_a_5_13_NC, in_a_5_14_NC, in_a_5_15_NC, in_a_6_0_NC, in_a_6_1_NC, in_a_6_2_NC, in_a_6_3_NC, in_a_6_4_NC, in_a_6_5_NC, in_a_6_6_NC, in_a_6_7_NC, in_a_6_8_NC, in_a_6_9_NC, in_a_6_10_NC, in_a_6_11_NC, in_a_6_12_NC, in_a_6_13_NC, in_a_6_14_NC, in_a_6_15_NC, in_a_7_0_NC, in_a_7_1_NC, in_a_7_2_NC, in_a_7_3_NC, in_a_7_4_NC, in_a_7_5_NC, in_a_7_6_NC, in_a_7_7_NC, in_a_7_8_NC, in_a_7_9_NC, in_a_7_10_NC, in_a_7_11_NC, in_a_7_12_NC, in_a_7_13_NC, in_a_7_14_NC, in_a_7_15_NC, in_a_8_0_NC, in_a_8_1_NC, in_a_8_2_NC, in_a_8_3_NC, in_a_8_4_NC, in_a_8_5_NC, in_a_8_6_NC, in_a_8_7_NC, in_a_8_8_NC, in_a_8_9_NC, in_a_8_10_NC, in_a_8_11_NC, in_a_8_12_NC, in_a_8_13_NC, in_a_8_14_NC, in_a_8_15_NC, in_a_9_0_NC, in_a_9_1_NC, in_a_9_2_NC, in_a_9_3_NC, in_a_9_4_NC, in_a_9_5_NC, in_a_9_6_NC, in_a_9_7_NC, in_a_9_8_NC, in_a_9_9_NC, in_a_9_10_NC, in_a_9_11_NC, in_a_9_12_NC, in_a_9_13_NC, in_a_9_14_NC, in_a_9_15_NC, in_a_10_0_NC, in_a_10_1_NC, in_a_10_2_NC, in_a_10_3_NC, in_a_10_4_NC, in_a_10_5_NC, in_a_10_6_NC, in_a_10_7_NC, in_a_10_8_NC, in_a_10_9_NC, in_a_10_10_NC, in_a_10_11_NC, in_a_10_12_NC, in_a_10_13_NC, in_a_10_14_NC, in_a_10_15_NC, in_a_11_0_NC, in_a_11_1_NC, in_a_11_2_NC, in_a_11_3_NC, in_a_11_4_NC, in_a_11_5_NC, in_a_11_6_NC, in_a_11_7_NC, in_a_11_8_NC, in_a_11_9_NC, in_a_11_10_NC, in_a_11_11_NC, in_a_11_12_NC, in_a_11_13_NC, in_a_11_14_NC, in_a_11_15_NC, in_a_12_0_NC, in_a_12_1_NC, in_a_12_2_NC, in_a_12_3_NC, in_a_12_4_NC, in_a_12_5_NC, in_a_12_6_NC, in_a_12_7_NC, in_a_12_8_NC, in_a_12_9_NC, in_a_12_10_NC, in_a_12_11_NC, in_a_12_12_NC, in_a_12_13_NC, in_a_12_14_NC, in_a_12_15_NC, in_a_13_0_NC, in_a_13_1_NC, in_a_13_2_NC, in_a_13_3_NC, in_a_13_4_NC, in_a_13_5_NC, in_a_13_6_NC, in_a_13_7_NC, in_a_13_8_NC, in_a_13_9_NC, in_a_13_10_NC, in_a_13_11_NC, in_a_13_12_NC, in_a_13_13_NC, in_a_13_14_NC, in_a_13_15_NC, in_a_14_0_NC, in_a_14_1_NC, in_a_14_2_NC, in_a_14_3_NC, in_a_14_4_NC, in_a_14_5_NC, in_a_14_6_NC, in_a_14_7_NC, in_a_14_8_NC, in_a_14_9_NC, in_a_14_10_NC, in_a_14_11_NC, in_a_14_12_NC, in_a_14_13_NC, in_a_14_14_NC, in_a_14_15_NC, in_a_15_0_NC, in_a_15_1_NC, in_a_15_2_NC, in_a_15_3_NC, in_a_15_4_NC, in_a_15_5_NC, in_a_15_6_NC, in_a_15_7_NC, in_a_15_8_NC, in_a_15_9_NC, in_a_15_10_NC, in_a_15_11_NC, in_a_15_12_NC, in_a_15_13_NC, in_a_15_14_NC, in_a_15_15_NC;

wire [`DWIDTH-1:0] in_a_chain_0_0_NC, in_a_chain_0_1_NC, in_a_chain_0_2_NC, in_a_chain_0_3_NC, in_a_chain_0_4_NC, in_a_chain_0_5_NC, in_a_chain_0_6_NC, in_a_chain_0_7_NC, in_a_chain_0_8_NC, in_a_chain_0_9_NC, in_a_chain_0_10_NC, in_a_chain_0_11_NC, in_a_chain_0_12_NC, in_a_chain_0_13_NC, in_a_chain_0_14_NC, in_a_chain_0_15_NC, in_a_chain_1_0_NC, in_a_chain_1_1_NC, in_a_chain_1_2_NC, in_a_chain_1_3_NC, in_a_chain_1_4_NC, in_a_chain_1_5_NC, in_a_chain_1_6_NC, in_a_chain_1_7_NC, in_a_chain_1_8_NC, in_a_chain_1_9_NC, in_a_chain_1_10_NC, in_a_chain_1_11_NC, in_a_chain_1_12_NC, in_a_chain_1_13_NC, in_a_chain_1_14_NC, in_a_chain_1_15_NC, in_a_chain_2_0_NC, in_a_chain_2_1_NC, in_a_chain_2_2_NC, in_a_chain_2_3_NC, in_a_chain_2_4_NC, in_a_chain_2_5_NC, in_a_chain_2_6_NC, in_a_chain_2_7_NC, in_a_chain_2_8_NC, in_a_chain_2_9_NC, in_a_chain_2_10_NC, in_a_chain_2_11_NC, in_a_chain_2_12_NC, in_a_chain_2_13_NC, in_a_chain_2_14_NC, in_a_chain_2_15_NC, in_a_chain_3_0_NC, in_a_chain_3_1_NC, in_a_chain_3_2_NC, in_a_chain_3_3_NC, in_a_chain_3_4_NC, in_a_chain_3_5_NC, in_a_chain_3_6_NC, in_a_chain_3_7_NC, in_a_chain_3_8_NC, in_a_chain_3_9_NC, in_a_chain_3_10_NC, in_a_chain_3_11_NC, in_a_chain_3_12_NC, in_a_chain_3_13_NC, in_a_chain_3_14_NC, in_a_chain_3_15_NC, in_a_chain_4_0_NC, in_a_chain_4_1_NC, in_a_chain_4_2_NC, in_a_chain_4_3_NC, in_a_chain_4_4_NC, in_a_chain_4_5_NC, in_a_chain_4_6_NC, in_a_chain_4_7_NC, in_a_chain_4_8_NC, in_a_chain_4_9_NC, in_a_chain_4_10_NC, in_a_chain_4_11_NC, in_a_chain_4_12_NC, in_a_chain_4_13_NC, in_a_chain_4_14_NC, in_a_chain_4_15_NC, in_a_chain_5_0_NC, in_a_chain_5_1_NC, in_a_chain_5_2_NC, in_a_chain_5_3_NC, in_a_chain_5_4_NC, in_a_chain_5_5_NC, in_a_chain_5_6_NC, in_a_chain_5_7_NC, in_a_chain_5_8_NC, in_a_chain_5_9_NC, in_a_chain_5_10_NC, in_a_chain_5_11_NC, in_a_chain_5_12_NC, in_a_chain_5_13_NC, in_a_chain_5_14_NC, in_a_chain_5_15_NC, in_a_chain_6_0_NC, in_a_chain_6_1_NC, in_a_chain_6_2_NC, in_a_chain_6_3_NC, in_a_chain_6_4_NC, in_a_chain_6_5_NC, in_a_chain_6_6_NC, in_a_chain_6_7_NC, in_a_chain_6_8_NC, in_a_chain_6_9_NC, in_a_chain_6_10_NC, in_a_chain_6_11_NC, in_a_chain_6_12_NC, in_a_chain_6_13_NC, in_a_chain_6_14_NC, in_a_chain_6_15_NC, in_a_chain_7_0_NC, in_a_chain_7_1_NC, in_a_chain_7_2_NC, in_a_chain_7_3_NC, in_a_chain_7_4_NC, in_a_chain_7_5_NC, in_a_chain_7_6_NC, in_a_chain_7_7_NC, in_a_chain_7_8_NC, in_a_chain_7_9_NC, in_a_chain_7_10_NC, in_a_chain_7_11_NC, in_a_chain_7_12_NC, in_a_chain_7_13_NC, in_a_chain_7_14_NC, in_a_chain_7_15_NC, in_a_chain_8_0_NC, in_a_chain_8_1_NC, in_a_chain_8_2_NC, in_a_chain_8_3_NC, in_a_chain_8_4_NC, in_a_chain_8_5_NC, in_a_chain_8_6_NC, in_a_chain_8_7_NC, in_a_chain_8_8_NC, in_a_chain_8_9_NC, in_a_chain_8_10_NC, in_a_chain_8_11_NC, in_a_chain_8_12_NC, in_a_chain_8_13_NC, in_a_chain_8_14_NC, in_a_chain_8_15_NC, in_a_chain_9_0_NC, in_a_chain_9_1_NC, in_a_chain_9_2_NC, in_a_chain_9_3_NC, in_a_chain_9_4_NC, in_a_chain_9_5_NC, in_a_chain_9_6_NC, in_a_chain_9_7_NC, in_a_chain_9_8_NC, in_a_chain_9_9_NC, in_a_chain_9_10_NC, in_a_chain_9_11_NC, in_a_chain_9_12_NC, in_a_chain_9_13_NC, in_a_chain_9_14_NC, in_a_chain_9_15_NC, in_a_chain_10_0_NC, in_a_chain_10_1_NC, in_a_chain_10_2_NC, in_a_chain_10_3_NC, in_a_chain_10_4_NC, in_a_chain_10_5_NC, in_a_chain_10_6_NC, in_a_chain_10_7_NC, in_a_chain_10_8_NC, in_a_chain_10_9_NC, in_a_chain_10_10_NC, in_a_chain_10_11_NC, in_a_chain_10_12_NC, in_a_chain_10_13_NC, in_a_chain_10_14_NC, in_a_chain_10_15_NC, in_a_chain_11_0_NC, in_a_chain_11_1_NC, in_a_chain_11_2_NC, in_a_chain_11_3_NC, in_a_chain_11_4_NC, in_a_chain_11_5_NC, in_a_chain_11_6_NC, in_a_chain_11_7_NC, in_a_chain_11_8_NC, in_a_chain_11_9_NC, in_a_chain_11_10_NC, in_a_chain_11_11_NC, in_a_chain_11_12_NC, in_a_chain_11_13_NC, in_a_chain_11_14_NC, in_a_chain_11_15_NC, in_a_chain_12_0_NC, in_a_chain_12_1_NC, in_a_chain_12_2_NC, in_a_chain_12_3_NC, in_a_chain_12_4_NC, in_a_chain_12_5_NC, in_a_chain_12_6_NC, in_a_chain_12_7_NC, in_a_chain_12_8_NC, in_a_chain_12_9_NC, in_a_chain_12_10_NC, in_a_chain_12_11_NC, in_a_chain_12_12_NC, in_a_chain_12_13_NC, in_a_chain_12_14_NC, in_a_chain_12_15_NC, in_a_chain_13_0_NC, in_a_chain_13_1_NC, in_a_chain_13_2_NC, in_a_chain_13_3_NC, in_a_chain_13_4_NC, in_a_chain_13_5_NC, in_a_chain_13_6_NC, in_a_chain_13_7_NC, in_a_chain_13_8_NC, in_a_chain_13_9_NC, in_a_chain_13_10_NC, in_a_chain_13_11_NC, in_a_chain_13_12_NC, in_a_chain_13_13_NC, in_a_chain_13_14_NC, in_a_chain_13_15_NC, in_a_chain_14_0_NC, in_a_chain_14_1_NC, in_a_chain_14_2_NC, in_a_chain_14_3_NC, in_a_chain_14_4_NC, in_a_chain_14_5_NC, in_a_chain_14_6_NC, in_a_chain_14_7_NC, in_a_chain_14_8_NC, in_a_chain_14_9_NC, in_a_chain_14_10_NC, in_a_chain_14_11_NC, in_a_chain_14_12_NC, in_a_chain_14_13_NC, in_a_chain_14_14_NC, in_a_chain_14_15_NC, in_a_chain_15_0_NC, in_a_chain_15_1_NC, in_a_chain_15_2_NC, in_a_chain_15_3_NC, in_a_chain_15_4_NC, in_a_chain_15_5_NC, in_a_chain_15_6_NC, in_a_chain_15_7_NC, in_a_chain_15_8_NC, in_a_chain_15_9_NC, in_a_chain_15_10_NC, in_a_chain_15_11_NC, in_a_chain_15_12_NC, in_a_chain_15_13_NC, in_a_chain_15_14_NC, in_a_chain_15_15_NC;

wire [`DWIDTH-1:0] out_a_0_0_NC, out_a_0_1_NC, out_a_0_2_NC, out_a_0_3_NC, out_a_0_4_NC, out_a_0_5_NC, out_a_0_6_NC, out_a_0_7_NC, out_a_0_8_NC, out_a_0_9_NC, out_a_0_10_NC, out_a_0_11_NC, out_a_0_12_NC, out_a_0_13_NC, out_a_0_14_NC, out_a_0_15_NC, out_a_1_0_NC, out_a_1_1_NC, out_a_1_2_NC, out_a_1_3_NC, out_a_1_4_NC, out_a_1_5_NC, out_a_1_6_NC, out_a_1_7_NC, out_a_1_8_NC, out_a_1_9_NC, out_a_1_10_NC, out_a_1_11_NC, out_a_1_12_NC, out_a_1_13_NC, out_a_1_14_NC, out_a_1_15_NC, out_a_2_0_NC, out_a_2_1_NC, out_a_2_2_NC, out_a_2_3_NC, out_a_2_4_NC, out_a_2_5_NC, out_a_2_6_NC, out_a_2_7_NC, out_a_2_8_NC, out_a_2_9_NC, out_a_2_10_NC, out_a_2_11_NC, out_a_2_12_NC, out_a_2_13_NC, out_a_2_14_NC, out_a_2_15_NC, out_a_3_0_NC, out_a_3_1_NC, out_a_3_2_NC, out_a_3_3_NC, out_a_3_4_NC, out_a_3_5_NC, out_a_3_6_NC, out_a_3_7_NC, out_a_3_8_NC, out_a_3_9_NC, out_a_3_10_NC, out_a_3_11_NC, out_a_3_12_NC, out_a_3_13_NC, out_a_3_14_NC, out_a_3_15_NC, out_a_4_0_NC, out_a_4_1_NC, out_a_4_2_NC, out_a_4_3_NC, out_a_4_4_NC, out_a_4_5_NC, out_a_4_6_NC, out_a_4_7_NC, out_a_4_8_NC, out_a_4_9_NC, out_a_4_10_NC, out_a_4_11_NC, out_a_4_12_NC, out_a_4_13_NC, out_a_4_14_NC, out_a_4_15_NC, out_a_5_0_NC, out_a_5_1_NC, out_a_5_2_NC, out_a_5_3_NC, out_a_5_4_NC, out_a_5_5_NC, out_a_5_6_NC, out_a_5_7_NC, out_a_5_8_NC, out_a_5_9_NC, out_a_5_10_NC, out_a_5_11_NC, out_a_5_12_NC, out_a_5_13_NC, out_a_5_14_NC, out_a_5_15_NC, out_a_6_0_NC, out_a_6_1_NC, out_a_6_2_NC, out_a_6_3_NC, out_a_6_4_NC, out_a_6_5_NC, out_a_6_6_NC, out_a_6_7_NC, out_a_6_8_NC, out_a_6_9_NC, out_a_6_10_NC, out_a_6_11_NC, out_a_6_12_NC, out_a_6_13_NC, out_a_6_14_NC, out_a_6_15_NC, out_a_7_0_NC, out_a_7_1_NC, out_a_7_2_NC, out_a_7_3_NC, out_a_7_4_NC, out_a_7_5_NC, out_a_7_6_NC, out_a_7_7_NC, out_a_7_8_NC, out_a_7_9_NC, out_a_7_10_NC, out_a_7_11_NC, out_a_7_12_NC, out_a_7_13_NC, out_a_7_14_NC, out_a_7_15_NC, out_a_8_0_NC, out_a_8_1_NC, out_a_8_2_NC, out_a_8_3_NC, out_a_8_4_NC, out_a_8_5_NC, out_a_8_6_NC, out_a_8_7_NC, out_a_8_8_NC, out_a_8_9_NC, out_a_8_10_NC, out_a_8_11_NC, out_a_8_12_NC, out_a_8_13_NC, out_a_8_14_NC, out_a_8_15_NC, out_a_9_0_NC, out_a_9_1_NC, out_a_9_2_NC, out_a_9_3_NC, out_a_9_4_NC, out_a_9_5_NC, out_a_9_6_NC, out_a_9_7_NC, out_a_9_8_NC, out_a_9_9_NC, out_a_9_10_NC, out_a_9_11_NC, out_a_9_12_NC, out_a_9_13_NC, out_a_9_14_NC, out_a_9_15_NC, out_a_10_0_NC, out_a_10_1_NC, out_a_10_2_NC, out_a_10_3_NC, out_a_10_4_NC, out_a_10_5_NC, out_a_10_6_NC, out_a_10_7_NC, out_a_10_8_NC, out_a_10_9_NC, out_a_10_10_NC, out_a_10_11_NC, out_a_10_12_NC, out_a_10_13_NC, out_a_10_14_NC, out_a_10_15_NC, out_a_11_0_NC, out_a_11_1_NC, out_a_11_2_NC, out_a_11_3_NC, out_a_11_4_NC, out_a_11_5_NC, out_a_11_6_NC, out_a_11_7_NC, out_a_11_8_NC, out_a_11_9_NC, out_a_11_10_NC, out_a_11_11_NC, out_a_11_12_NC, out_a_11_13_NC, out_a_11_14_NC, out_a_11_15_NC, out_a_12_0_NC, out_a_12_1_NC, out_a_12_2_NC, out_a_12_3_NC, out_a_12_4_NC, out_a_12_5_NC, out_a_12_6_NC, out_a_12_7_NC, out_a_12_8_NC, out_a_12_9_NC, out_a_12_10_NC, out_a_12_11_NC, out_a_12_12_NC, out_a_12_13_NC, out_a_12_14_NC, out_a_12_15_NC, out_a_13_0_NC, out_a_13_1_NC, out_a_13_2_NC, out_a_13_3_NC, out_a_13_4_NC, out_a_13_5_NC, out_a_13_6_NC, out_a_13_7_NC, out_a_13_8_NC, out_a_13_9_NC, out_a_13_10_NC, out_a_13_11_NC, out_a_13_12_NC, out_a_13_13_NC, out_a_13_14_NC, out_a_13_15_NC, out_a_14_0_NC, out_a_14_1_NC, out_a_14_2_NC, out_a_14_3_NC, out_a_14_4_NC, out_a_14_5_NC, out_a_14_6_NC, out_a_14_7_NC, out_a_14_8_NC, out_a_14_9_NC, out_a_14_10_NC, out_a_14_11_NC, out_a_14_12_NC, out_a_14_13_NC, out_a_14_14_NC, out_a_14_15_NC, out_a_15_0_NC, out_a_15_1_NC, out_a_15_2_NC, out_a_15_3_NC, out_a_15_4_NC, out_a_15_5_NC, out_a_15_6_NC, out_a_15_7_NC, out_a_15_8_NC, out_a_15_9_NC, out_a_15_10_NC, out_a_15_11_NC, out_a_15_12_NC, out_a_15_13_NC, out_a_15_14_NC, out_a_15_15_NC;

processing_element pe0_0(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel),             .in_a(a0),    .in_a_chain(in_a_chain_0_0_NC),  .in_b(b0),      .in_c(c0),        .out_a(out_a_0_0_NC), .out_a_chain(a0_0to0_1), .out_b(b0_0to1_0), .out_b0(b0_0to1_0_ping), .out_b1(b0_0to1_0_pong), .out_c(matrixC0_0), .b_data_valid_ping(b_data_valid_ping),         .b_data_valid_pong(b_data_valid_pong        ), .mode(1'b1));
processing_element pe0_1(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay1), .in_a(in_a_0_1_NC), .in_a_chain(a0_0to0_1), .in_b(b1),      .in_c(c1),        .out_a(out_a_0_1_NC), .out_a_chain(a0_1to0_2), .out_b(b0_1to1_1), .out_b0(b0_1to1_1_ping), .out_b1(b0_1to1_1_pong), .out_c(matrixC0_1), .b_data_valid_ping(b_data_valid_ping_delay0_1), .b_data_valid_pong(b_data_valid_pong_delay0_1), .mode(1'b0));
processing_element pe0_2(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay2), .in_a(in_a_0_2_NC), .in_a_chain(a0_1to0_2), .in_b(b2),      .in_c(c2),        .out_a(out_a_0_2_NC), .out_a_chain(a0_2to0_3), .out_b(b0_2to1_2), .out_b0(b0_2to1_2_ping), .out_b1(b0_2to1_2_pong), .out_c(matrixC0_2), .b_data_valid_ping(b_data_valid_ping_delay0_2), .b_data_valid_pong(b_data_valid_pong_delay0_2), .mode(1'b0));
processing_element pe0_3(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay3), .in_a(in_a_0_3_NC), .in_a_chain(a0_2to0_3), .in_b(b3),      .in_c(c3),        .out_a(out_a_0_3_NC), .out_a_chain(a0_3to0_4), .out_b(b0_3to1_3), .out_b0(b0_3to1_3_ping), .out_b1(b0_3to1_3_pong), .out_c(matrixC0_3), .b_data_valid_ping(b_data_valid_ping_delay0_3), .b_data_valid_pong(b_data_valid_pong_delay0_3), .mode(1'b0));
processing_element pe0_4(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay4), .in_a(in_a_0_4_NC), .in_a_chain(a0_3to0_4), .in_b(b4),      .in_c(c4),        .out_a(out_a_0_4_NC), .out_a_chain(a0_4to0_5), .out_b(b0_4to1_4), .out_b0(b0_4to1_4_ping), .out_b1(b0_4to1_4_pong), .out_c(matrixC0_4), .b_data_valid_ping(b_data_valid_ping_delay0_4), .b_data_valid_pong(b_data_valid_pong_delay0_4), .mode(1'b0));
processing_element pe0_5(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay5), .in_a(in_a_0_5_NC), .in_a_chain(a0_4to0_5), .in_b(b5),      .in_c(c5),        .out_a(out_a_0_5_NC), .out_a_chain(a0_5to0_6), .out_b(b0_5to1_5), .out_b0(b0_5to1_5_ping), .out_b1(b0_5to1_5_pong), .out_c(matrixC0_5), .b_data_valid_ping(b_data_valid_ping_delay0_5), .b_data_valid_pong(b_data_valid_pong_delay0_5), .mode(1'b0));
processing_element pe0_6(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay6), .in_a(in_a_0_6_NC), .in_a_chain(a0_5to0_6), .in_b(b6),      .in_c(c6),        .out_a(out_a_0_6_NC), .out_a_chain(a0_6to0_7), .out_b(b0_6to1_6), .out_b0(b0_6to1_6_ping), .out_b1(b0_6to1_6_pong), .out_c(matrixC0_6), .b_data_valid_ping(b_data_valid_ping_delay0_6), .b_data_valid_pong(b_data_valid_pong_delay0_6), .mode(1'b0));
processing_element pe0_7(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay7), .in_a(in_a_0_7_NC), .in_a_chain(a0_6to0_7), .in_b(b7),      .in_c(c7),        .out_a(out_a_0_7_NC), .out_a_chain(a0_7to0_8), .out_b(b0_7to1_7), .out_b0(b0_7to1_7_ping), .out_b1(b0_7to1_7_pong), .out_c(matrixC0_7), .b_data_valid_ping(b_data_valid_ping_delay0_7), .b_data_valid_pong(b_data_valid_pong_delay0_7), .mode(1'b0));
processing_element pe0_8(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay8), .in_a(in_a_0_8_NC), .in_a_chain(a0_7to0_8), .in_b(b8),      .in_c(c8),        .out_a(out_a_0_8_NC), .out_a_chain(a0_8to0_9), .out_b(b0_8to1_8), .out_b0(b0_8to1_8_ping), .out_b1(b0_8to1_8_pong), .out_c(matrixC0_8), .b_data_valid_ping(b_data_valid_ping_delay0_8), .b_data_valid_pong(b_data_valid_pong_delay0_8), .mode(1'b0));
processing_element pe0_9(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay9), .in_a(in_a_0_9_NC), .in_a_chain(a0_8to0_9), .in_b(b9),      .in_c(c9),        .out_a(out_a_0_9_NC), .out_a_chain(a0_9to0_10), .out_b(b0_9to1_9), .out_b0(b0_9to1_9_ping), .out_b1(b0_9to1_9_pong), .out_c(matrixC0_9), .b_data_valid_ping(b_data_valid_ping_delay0_9), .b_data_valid_pong(b_data_valid_pong_delay0_9), .mode(1'b0));
processing_element pe0_10(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay10), .in_a(in_a_0_10_NC), .in_a_chain(a0_9to0_10), .in_b(b10),      .in_c(c10),        .out_a(out_a_0_10_NC), .out_a_chain(a0_10to0_11), .out_b(b0_10to1_10), .out_b0(b0_10to1_10_ping), .out_b1(b0_10to1_10_pong), .out_c(matrixC0_10), .b_data_valid_ping(b_data_valid_ping_delay0_10), .b_data_valid_pong(b_data_valid_pong_delay0_10), .mode(1'b0));
processing_element pe0_11(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay11), .in_a(in_a_0_11_NC), .in_a_chain(a0_10to0_11), .in_b(b11),      .in_c(c11),        .out_a(out_a_0_11_NC), .out_a_chain(a0_11to0_12), .out_b(b0_11to1_11), .out_b0(b0_11to1_11_ping), .out_b1(b0_11to1_11_pong), .out_c(matrixC0_11), .b_data_valid_ping(b_data_valid_ping_delay0_11), .b_data_valid_pong(b_data_valid_pong_delay0_11), .mode(1'b0));
processing_element pe0_12(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay12), .in_a(in_a_0_12_NC), .in_a_chain(a0_11to0_12), .in_b(b12),      .in_c(c12),        .out_a(out_a_0_12_NC), .out_a_chain(a0_12to0_13), .out_b(b0_12to1_12), .out_b0(b0_12to1_12_ping), .out_b1(b0_12to1_12_pong), .out_c(matrixC0_12), .b_data_valid_ping(b_data_valid_ping_delay0_12), .b_data_valid_pong(b_data_valid_pong_delay0_12), .mode(1'b0));
processing_element pe0_13(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay13), .in_a(in_a_0_13_NC), .in_a_chain(a0_12to0_13), .in_b(b13),      .in_c(c13),        .out_a(out_a_0_13_NC), .out_a_chain(a0_13to0_14), .out_b(b0_13to1_13), .out_b0(b0_13to1_13_ping), .out_b1(b0_13to1_13_pong), .out_c(matrixC0_13), .b_data_valid_ping(b_data_valid_ping_delay0_13), .b_data_valid_pong(b_data_valid_pong_delay0_13), .mode(1'b0));
processing_element pe0_14(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay14), .in_a(in_a_0_14_NC), .in_a_chain(a0_13to0_14), .in_b(b14),      .in_c(c14),        .out_a(out_a_0_14_NC), .out_a_chain(a0_14to0_15), .out_b(b0_14to1_14), .out_b0(b0_14to1_14_ping), .out_b1(b0_14to1_14_pong), .out_c(matrixC0_14), .b_data_valid_ping(b_data_valid_ping_delay0_14), .b_data_valid_pong(b_data_valid_pong_delay0_14), .mode(1'b0));
processing_element pe0_15(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay15), .in_a(in_a_0_15_NC), .in_a_chain(a0_14to0_15), .in_b(b15),      .in_c(c15),        .out_a(out_a_0_15_NC), .out_a_chain(a0_15to0_16), .out_b(b0_15to1_15), .out_b0(b0_15to1_15_ping), .out_b1(b0_15to1_15_pong), .out_c(matrixC0_15), .b_data_valid_ping(b_data_valid_ping_delay0_15), .b_data_valid_pong(b_data_valid_pong_delay0_15), .mode(1'b0));
processing_element pe1_0(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay1), .in_a(a1),   .in_a_chain(in_a_chain_1_0_NC),   .in_b(b0_0to1_0), .in_c(matrixC0_0), .out_a(out_a_1_0_NC), .out_a_chain(a1_0to1_1), .out_b(b1_0to2_0), .out_b0(b1_0to2_0_ping), .out_b1(b1_0to2_0_pong), .out_c(matrixC1_0), .b_data_valid_ping(b_data_valid_ping_delay1_0), .b_data_valid_pong(b_data_valid_pong_delay1_0), .mode(1'b1));
processing_element pe1_1(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay2), .in_a(in_a_1_1_NC),  .in_a_chain(a1_0to1_1), .in_b(b0_1to1_1), .in_c(matrixC0_1), .out_a(out_a_1_1_NC), .out_a_chain(a1_1to1_2), .out_b(b1_1to2_1), .out_b0(b1_1to2_1_ping), .out_b1(b1_1to2_1_pong), .out_c(matrixC1_1), .b_data_valid_ping(b_data_valid_ping_delay1_1), .b_data_valid_pong(b_data_valid_pong_delay1_1), .mode(1'b0));
processing_element pe1_2(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay3), .in_a(in_a_1_2_NC),  .in_a_chain(a1_1to1_2), .in_b(b0_2to1_2), .in_c(matrixC0_2), .out_a(out_a_1_2_NC), .out_a_chain(a1_2to1_3), .out_b(b1_2to2_2), .out_b0(b1_2to2_2_ping), .out_b1(b1_2to2_2_pong), .out_c(matrixC1_2), .b_data_valid_ping(b_data_valid_ping_delay1_2), .b_data_valid_pong(b_data_valid_pong_delay1_2), .mode(1'b0));
processing_element pe1_3(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay4), .in_a(in_a_1_3_NC),  .in_a_chain(a1_2to1_3), .in_b(b0_3to1_3), .in_c(matrixC0_3), .out_a(out_a_1_3_NC), .out_a_chain(a1_3to1_4), .out_b(b1_3to2_3), .out_b0(b1_3to2_3_ping), .out_b1(b1_3to2_3_pong), .out_c(matrixC1_3), .b_data_valid_ping(b_data_valid_ping_delay1_3), .b_data_valid_pong(b_data_valid_pong_delay1_3), .mode(1'b0));
processing_element pe1_4(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay5), .in_a(in_a_1_4_NC),  .in_a_chain(a1_3to1_4), .in_b(b0_4to1_4), .in_c(matrixC0_4), .out_a(out_a_1_4_NC), .out_a_chain(a1_4to1_5), .out_b(b1_4to2_4), .out_b0(b1_4to2_4_ping), .out_b1(b1_4to2_4_pong), .out_c(matrixC1_4), .b_data_valid_ping(b_data_valid_ping_delay1_4), .b_data_valid_pong(b_data_valid_pong_delay1_4), .mode(1'b0));
processing_element pe1_5(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay6), .in_a(in_a_1_5_NC),  .in_a_chain(a1_4to1_5), .in_b(b0_5to1_5), .in_c(matrixC0_5), .out_a(out_a_1_5_NC), .out_a_chain(a1_5to1_6), .out_b(b1_5to2_5), .out_b0(b1_5to2_5_ping), .out_b1(b1_5to2_5_pong), .out_c(matrixC1_5), .b_data_valid_ping(b_data_valid_ping_delay1_5), .b_data_valid_pong(b_data_valid_pong_delay1_5), .mode(1'b0));
processing_element pe1_6(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay7), .in_a(in_a_1_6_NC),  .in_a_chain(a1_5to1_6), .in_b(b0_6to1_6), .in_c(matrixC0_6), .out_a(out_a_1_6_NC), .out_a_chain(a1_6to1_7), .out_b(b1_6to2_6), .out_b0(b1_6to2_6_ping), .out_b1(b1_6to2_6_pong), .out_c(matrixC1_6), .b_data_valid_ping(b_data_valid_ping_delay1_6), .b_data_valid_pong(b_data_valid_pong_delay1_6), .mode(1'b0));
processing_element pe1_7(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay8), .in_a(in_a_1_7_NC),  .in_a_chain(a1_6to1_7), .in_b(b0_7to1_7), .in_c(matrixC0_7), .out_a(out_a_1_7_NC), .out_a_chain(a1_7to1_8), .out_b(b1_7to2_7), .out_b0(b1_7to2_7_ping), .out_b1(b1_7to2_7_pong), .out_c(matrixC1_7), .b_data_valid_ping(b_data_valid_ping_delay1_7), .b_data_valid_pong(b_data_valid_pong_delay1_7), .mode(1'b0));
processing_element pe1_8(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay9), .in_a(in_a_1_8_NC),  .in_a_chain(a1_7to1_8), .in_b(b0_8to1_8), .in_c(matrixC0_8), .out_a(out_a_1_8_NC), .out_a_chain(a1_8to1_9), .out_b(b1_8to2_8), .out_b0(b1_8to2_8_ping), .out_b1(b1_8to2_8_pong), .out_c(matrixC1_8), .b_data_valid_ping(b_data_valid_ping_delay1_8), .b_data_valid_pong(b_data_valid_pong_delay1_8), .mode(1'b0));
processing_element pe1_9(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay10), .in_a(in_a_1_9_NC),  .in_a_chain(a1_8to1_9), .in_b(b0_9to1_9), .in_c(matrixC0_9), .out_a(out_a_1_9_NC), .out_a_chain(a1_9to1_10), .out_b(b1_9to2_9), .out_b0(b1_9to2_9_ping), .out_b1(b1_9to2_9_pong), .out_c(matrixC1_9), .b_data_valid_ping(b_data_valid_ping_delay1_9), .b_data_valid_pong(b_data_valid_pong_delay1_9), .mode(1'b0));
processing_element pe1_10(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay11), .in_a(in_a_1_10_NC),  .in_a_chain(a1_9to1_10), .in_b(b0_10to1_10), .in_c(matrixC0_10), .out_a(out_a_1_10_NC), .out_a_chain(a1_10to1_11), .out_b(b1_10to2_10), .out_b0(b1_10to2_10_ping), .out_b1(b1_10to2_10_pong), .out_c(matrixC1_10), .b_data_valid_ping(b_data_valid_ping_delay1_10), .b_data_valid_pong(b_data_valid_pong_delay1_10), .mode(1'b0));
processing_element pe1_11(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay12), .in_a(in_a_1_11_NC),  .in_a_chain(a1_10to1_11), .in_b(b0_11to1_11), .in_c(matrixC0_11), .out_a(out_a_1_11_NC), .out_a_chain(a1_11to1_12), .out_b(b1_11to2_11), .out_b0(b1_11to2_11_ping), .out_b1(b1_11to2_11_pong), .out_c(matrixC1_11), .b_data_valid_ping(b_data_valid_ping_delay1_11), .b_data_valid_pong(b_data_valid_pong_delay1_11), .mode(1'b0));
processing_element pe1_12(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay13), .in_a(in_a_1_12_NC),  .in_a_chain(a1_11to1_12), .in_b(b0_12to1_12), .in_c(matrixC0_12), .out_a(out_a_1_12_NC), .out_a_chain(a1_12to1_13), .out_b(b1_12to2_12), .out_b0(b1_12to2_12_ping), .out_b1(b1_12to2_12_pong), .out_c(matrixC1_12), .b_data_valid_ping(b_data_valid_ping_delay1_12), .b_data_valid_pong(b_data_valid_pong_delay1_12), .mode(1'b0));
processing_element pe1_13(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay14), .in_a(in_a_1_13_NC),  .in_a_chain(a1_12to1_13), .in_b(b0_13to1_13), .in_c(matrixC0_13), .out_a(out_a_1_13_NC), .out_a_chain(a1_13to1_14), .out_b(b1_13to2_13), .out_b0(b1_13to2_13_ping), .out_b1(b1_13to2_13_pong), .out_c(matrixC1_13), .b_data_valid_ping(b_data_valid_ping_delay1_13), .b_data_valid_pong(b_data_valid_pong_delay1_13), .mode(1'b0));
processing_element pe1_14(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay15), .in_a(in_a_1_14_NC),  .in_a_chain(a1_13to1_14), .in_b(b0_14to1_14), .in_c(matrixC0_14), .out_a(out_a_1_14_NC), .out_a_chain(a1_14to1_15), .out_b(b1_14to2_14), .out_b0(b1_14to2_14_ping), .out_b1(b1_14to2_14_pong), .out_c(matrixC1_14), .b_data_valid_ping(b_data_valid_ping_delay1_14), .b_data_valid_pong(b_data_valid_pong_delay1_14), .mode(1'b0));
processing_element pe1_15(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay16), .in_a(in_a_1_15_NC),  .in_a_chain(a1_14to1_15), .in_b(b0_15to1_15), .in_c(matrixC0_15), .out_a(out_a_1_15_NC), .out_a_chain(a1_15to1_16), .out_b(b1_15to2_15), .out_b0(b1_15to2_15_ping), .out_b1(b1_15to2_15_pong), .out_c(matrixC1_15), .b_data_valid_ping(b_data_valid_ping_delay1_15), .b_data_valid_pong(b_data_valid_pong_delay1_15), .mode(1'b0));
processing_element pe2_0(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay2), .in_a(a2),   .in_a_chain(in_a_chain_2_0_NC),   .in_b(b1_0to2_0), .in_c(matrixC1_0), .out_a(out_a_2_0_NC), .out_a_chain(a2_0to2_1), .out_b(b2_0to3_0), .out_b0(b2_0to3_0_ping), .out_b1(b2_0to3_0_pong), .out_c(matrixC2_0), .b_data_valid_ping(b_data_valid_ping_delay2_0), .b_data_valid_pong(b_data_valid_pong_delay2_0), .mode(1'b1));
processing_element pe2_1(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay3), .in_a(in_a_2_1_NC),  .in_a_chain(a2_0to2_1), .in_b(b1_1to2_1), .in_c(matrixC1_1), .out_a(out_a_2_1_NC), .out_a_chain(a2_1to2_2), .out_b(b2_1to3_1), .out_b0(b2_1to3_1_ping), .out_b1(b2_1to3_1_pong), .out_c(matrixC2_1), .b_data_valid_ping(b_data_valid_ping_delay2_1), .b_data_valid_pong(b_data_valid_pong_delay2_1), .mode(1'b0));
processing_element pe2_2(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay4), .in_a(in_a_2_2_NC),  .in_a_chain(a2_1to2_2), .in_b(b1_2to2_2), .in_c(matrixC1_2), .out_a(out_a_2_2_NC), .out_a_chain(a2_2to2_3), .out_b(b2_2to3_2), .out_b0(b2_2to3_2_ping), .out_b1(b2_2to3_2_pong), .out_c(matrixC2_2), .b_data_valid_ping(b_data_valid_ping_delay2_2), .b_data_valid_pong(b_data_valid_pong_delay2_2), .mode(1'b0));
processing_element pe2_3(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay5), .in_a(in_a_2_3_NC),  .in_a_chain(a2_2to2_3), .in_b(b1_3to2_3), .in_c(matrixC1_3), .out_a(out_a_2_3_NC), .out_a_chain(a2_3to2_4), .out_b(b2_3to3_3), .out_b0(b2_3to3_3_ping), .out_b1(b2_3to3_3_pong), .out_c(matrixC2_3), .b_data_valid_ping(b_data_valid_ping_delay2_3), .b_data_valid_pong(b_data_valid_pong_delay2_3), .mode(1'b0));
processing_element pe2_4(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay6), .in_a(in_a_2_4_NC),  .in_a_chain(a2_3to2_4), .in_b(b1_4to2_4), .in_c(matrixC1_4), .out_a(out_a_2_4_NC), .out_a_chain(a2_4to2_5), .out_b(b2_4to3_4), .out_b0(b2_4to3_4_ping), .out_b1(b2_4to3_4_pong), .out_c(matrixC2_4), .b_data_valid_ping(b_data_valid_ping_delay2_4), .b_data_valid_pong(b_data_valid_pong_delay2_4), .mode(1'b0));
processing_element pe2_5(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay7), .in_a(in_a_2_5_NC),  .in_a_chain(a2_4to2_5), .in_b(b1_5to2_5), .in_c(matrixC1_5), .out_a(out_a_2_5_NC), .out_a_chain(a2_5to2_6), .out_b(b2_5to3_5), .out_b0(b2_5to3_5_ping), .out_b1(b2_5to3_5_pong), .out_c(matrixC2_5), .b_data_valid_ping(b_data_valid_ping_delay2_5), .b_data_valid_pong(b_data_valid_pong_delay2_5), .mode(1'b0));
processing_element pe2_6(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay8), .in_a(in_a_2_6_NC),  .in_a_chain(a2_5to2_6), .in_b(b1_6to2_6), .in_c(matrixC1_6), .out_a(out_a_2_6_NC), .out_a_chain(a2_6to2_7), .out_b(b2_6to3_6), .out_b0(b2_6to3_6_ping), .out_b1(b2_6to3_6_pong), .out_c(matrixC2_6), .b_data_valid_ping(b_data_valid_ping_delay2_6), .b_data_valid_pong(b_data_valid_pong_delay2_6), .mode(1'b0));
processing_element pe2_7(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay9), .in_a(in_a_2_7_NC),  .in_a_chain(a2_6to2_7), .in_b(b1_7to2_7), .in_c(matrixC1_7), .out_a(out_a_2_7_NC), .out_a_chain(a2_7to2_8), .out_b(b2_7to3_7), .out_b0(b2_7to3_7_ping), .out_b1(b2_7to3_7_pong), .out_c(matrixC2_7), .b_data_valid_ping(b_data_valid_ping_delay2_7), .b_data_valid_pong(b_data_valid_pong_delay2_7), .mode(1'b0));
processing_element pe2_8(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay10), .in_a(in_a_2_8_NC),  .in_a_chain(a2_7to2_8), .in_b(b1_8to2_8), .in_c(matrixC1_8), .out_a(out_a_2_8_NC), .out_a_chain(a2_8to2_9), .out_b(b2_8to3_8), .out_b0(b2_8to3_8_ping), .out_b1(b2_8to3_8_pong), .out_c(matrixC2_8), .b_data_valid_ping(b_data_valid_ping_delay2_8), .b_data_valid_pong(b_data_valid_pong_delay2_8), .mode(1'b0));
processing_element pe2_9(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay11), .in_a(in_a_2_9_NC),  .in_a_chain(a2_8to2_9), .in_b(b1_9to2_9), .in_c(matrixC1_9), .out_a(out_a_2_9_NC), .out_a_chain(a2_9to2_10), .out_b(b2_9to3_9), .out_b0(b2_9to3_9_ping), .out_b1(b2_9to3_9_pong), .out_c(matrixC2_9), .b_data_valid_ping(b_data_valid_ping_delay2_9), .b_data_valid_pong(b_data_valid_pong_delay2_9), .mode(1'b0));
processing_element pe2_10(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay12), .in_a(in_a_2_10_NC),  .in_a_chain(a2_9to2_10), .in_b(b1_10to2_10), .in_c(matrixC1_10), .out_a(out_a_2_10_NC), .out_a_chain(a2_10to2_11), .out_b(b2_10to3_10), .out_b0(b2_10to3_10_ping), .out_b1(b2_10to3_10_pong), .out_c(matrixC2_10), .b_data_valid_ping(b_data_valid_ping_delay2_10), .b_data_valid_pong(b_data_valid_pong_delay2_10), .mode(1'b0));
processing_element pe2_11(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay13), .in_a(in_a_2_11_NC),  .in_a_chain(a2_10to2_11), .in_b(b1_11to2_11), .in_c(matrixC1_11), .out_a(out_a_2_11_NC), .out_a_chain(a2_11to2_12), .out_b(b2_11to3_11), .out_b0(b2_11to3_11_ping), .out_b1(b2_11to3_11_pong), .out_c(matrixC2_11), .b_data_valid_ping(b_data_valid_ping_delay2_11), .b_data_valid_pong(b_data_valid_pong_delay2_11), .mode(1'b0));
processing_element pe2_12(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay14), .in_a(in_a_2_12_NC),  .in_a_chain(a2_11to2_12), .in_b(b1_12to2_12), .in_c(matrixC1_12), .out_a(out_a_2_12_NC), .out_a_chain(a2_12to2_13), .out_b(b2_12to3_12), .out_b0(b2_12to3_12_ping), .out_b1(b2_12to3_12_pong), .out_c(matrixC2_12), .b_data_valid_ping(b_data_valid_ping_delay2_12), .b_data_valid_pong(b_data_valid_pong_delay2_12), .mode(1'b0));
processing_element pe2_13(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay15), .in_a(in_a_2_13_NC),  .in_a_chain(a2_12to2_13), .in_b(b1_13to2_13), .in_c(matrixC1_13), .out_a(out_a_2_13_NC), .out_a_chain(a2_13to2_14), .out_b(b2_13to3_13), .out_b0(b2_13to3_13_ping), .out_b1(b2_13to3_13_pong), .out_c(matrixC2_13), .b_data_valid_ping(b_data_valid_ping_delay2_13), .b_data_valid_pong(b_data_valid_pong_delay2_13), .mode(1'b0));
processing_element pe2_14(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay16), .in_a(in_a_2_14_NC),  .in_a_chain(a2_13to2_14), .in_b(b1_14to2_14), .in_c(matrixC1_14), .out_a(out_a_2_14_NC), .out_a_chain(a2_14to2_15), .out_b(b2_14to3_14), .out_b0(b2_14to3_14_ping), .out_b1(b2_14to3_14_pong), .out_c(matrixC2_14), .b_data_valid_ping(b_data_valid_ping_delay2_14), .b_data_valid_pong(b_data_valid_pong_delay2_14), .mode(1'b0));
processing_element pe2_15(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay17), .in_a(in_a_2_15_NC),  .in_a_chain(a2_14to2_15), .in_b(b1_15to2_15), .in_c(matrixC1_15), .out_a(out_a_2_15_NC), .out_a_chain(a2_15to2_16), .out_b(b2_15to3_15), .out_b0(b2_15to3_15_ping), .out_b1(b2_15to3_15_pong), .out_c(matrixC2_15), .b_data_valid_ping(b_data_valid_ping_delay2_15), .b_data_valid_pong(b_data_valid_pong_delay2_15), .mode(1'b0));
processing_element pe3_0(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay3), .in_a(a3),   .in_a_chain(in_a_chain_3_0_NC),   .in_b(b2_0to3_0), .in_c(matrixC2_0), .out_a(out_a_3_0_NC), .out_a_chain(a3_0to3_1), .out_b(b3_0to4_0), .out_b0(b3_0to4_0_ping), .out_b1(b3_0to4_0_pong), .out_c(matrixC3_0), .b_data_valid_ping(b_data_valid_ping_delay3_0), .b_data_valid_pong(b_data_valid_pong_delay3_0), .mode(1'b1));
processing_element pe3_1(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay4), .in_a(in_a_3_1_NC),  .in_a_chain(a3_0to3_1), .in_b(b2_1to3_1), .in_c(matrixC2_1), .out_a(out_a_3_1_NC), .out_a_chain(a3_1to3_2), .out_b(b3_1to4_1), .out_b0(b3_1to4_1_ping), .out_b1(b3_1to4_1_pong), .out_c(matrixC3_1), .b_data_valid_ping(b_data_valid_ping_delay3_1), .b_data_valid_pong(b_data_valid_pong_delay3_1), .mode(1'b0));
processing_element pe3_2(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay5), .in_a(in_a_3_2_NC),  .in_a_chain(a3_1to3_2), .in_b(b2_2to3_2), .in_c(matrixC2_2), .out_a(out_a_3_2_NC), .out_a_chain(a3_2to3_3), .out_b(b3_2to4_2), .out_b0(b3_2to4_2_ping), .out_b1(b3_2to4_2_pong), .out_c(matrixC3_2), .b_data_valid_ping(b_data_valid_ping_delay3_2), .b_data_valid_pong(b_data_valid_pong_delay3_2), .mode(1'b0));
processing_element pe3_3(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay6), .in_a(in_a_3_3_NC),  .in_a_chain(a3_2to3_3), .in_b(b2_3to3_3), .in_c(matrixC2_3), .out_a(out_a_3_3_NC), .out_a_chain(a3_3to3_4), .out_b(b3_3to4_3), .out_b0(b3_3to4_3_ping), .out_b1(b3_3to4_3_pong), .out_c(matrixC3_3), .b_data_valid_ping(b_data_valid_ping_delay3_3), .b_data_valid_pong(b_data_valid_pong_delay3_3), .mode(1'b0));
processing_element pe3_4(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay7), .in_a(in_a_3_4_NC),  .in_a_chain(a3_3to3_4), .in_b(b2_4to3_4), .in_c(matrixC2_4), .out_a(out_a_3_4_NC), .out_a_chain(a3_4to3_5), .out_b(b3_4to4_4), .out_b0(b3_4to4_4_ping), .out_b1(b3_4to4_4_pong), .out_c(matrixC3_4), .b_data_valid_ping(b_data_valid_ping_delay3_4), .b_data_valid_pong(b_data_valid_pong_delay3_4), .mode(1'b0));
processing_element pe3_5(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay8), .in_a(in_a_3_5_NC),  .in_a_chain(a3_4to3_5), .in_b(b2_5to3_5), .in_c(matrixC2_5), .out_a(out_a_3_5_NC), .out_a_chain(a3_5to3_6), .out_b(b3_5to4_5), .out_b0(b3_5to4_5_ping), .out_b1(b3_5to4_5_pong), .out_c(matrixC3_5), .b_data_valid_ping(b_data_valid_ping_delay3_5), .b_data_valid_pong(b_data_valid_pong_delay3_5), .mode(1'b0));
processing_element pe3_6(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay9), .in_a(in_a_3_6_NC),  .in_a_chain(a3_5to3_6), .in_b(b2_6to3_6), .in_c(matrixC2_6), .out_a(out_a_3_6_NC), .out_a_chain(a3_6to3_7), .out_b(b3_6to4_6), .out_b0(b3_6to4_6_ping), .out_b1(b3_6to4_6_pong), .out_c(matrixC3_6), .b_data_valid_ping(b_data_valid_ping_delay3_6), .b_data_valid_pong(b_data_valid_pong_delay3_6), .mode(1'b0));
processing_element pe3_7(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay10), .in_a(in_a_3_7_NC),  .in_a_chain(a3_6to3_7), .in_b(b2_7to3_7), .in_c(matrixC2_7), .out_a(out_a_3_7_NC), .out_a_chain(a3_7to3_8), .out_b(b3_7to4_7), .out_b0(b3_7to4_7_ping), .out_b1(b3_7to4_7_pong), .out_c(matrixC3_7), .b_data_valid_ping(b_data_valid_ping_delay3_7), .b_data_valid_pong(b_data_valid_pong_delay3_7), .mode(1'b0));
processing_element pe3_8(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay11), .in_a(in_a_3_8_NC),  .in_a_chain(a3_7to3_8), .in_b(b2_8to3_8), .in_c(matrixC2_8), .out_a(out_a_3_8_NC), .out_a_chain(a3_8to3_9), .out_b(b3_8to4_8), .out_b0(b3_8to4_8_ping), .out_b1(b3_8to4_8_pong), .out_c(matrixC3_8), .b_data_valid_ping(b_data_valid_ping_delay3_8), .b_data_valid_pong(b_data_valid_pong_delay3_8), .mode(1'b0));
processing_element pe3_9(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay12), .in_a(in_a_3_9_NC),  .in_a_chain(a3_8to3_9), .in_b(b2_9to3_9), .in_c(matrixC2_9), .out_a(out_a_3_9_NC), .out_a_chain(a3_9to3_10), .out_b(b3_9to4_9), .out_b0(b3_9to4_9_ping), .out_b1(b3_9to4_9_pong), .out_c(matrixC3_9), .b_data_valid_ping(b_data_valid_ping_delay3_9), .b_data_valid_pong(b_data_valid_pong_delay3_9), .mode(1'b0));
processing_element pe3_10(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay13), .in_a(in_a_3_10_NC),  .in_a_chain(a3_9to3_10), .in_b(b2_10to3_10), .in_c(matrixC2_10), .out_a(out_a_3_10_NC), .out_a_chain(a3_10to3_11), .out_b(b3_10to4_10), .out_b0(b3_10to4_10_ping), .out_b1(b3_10to4_10_pong), .out_c(matrixC3_10), .b_data_valid_ping(b_data_valid_ping_delay3_10), .b_data_valid_pong(b_data_valid_pong_delay3_10), .mode(1'b0));
processing_element pe3_11(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay14), .in_a(in_a_3_11_NC),  .in_a_chain(a3_10to3_11), .in_b(b2_11to3_11), .in_c(matrixC2_11), .out_a(out_a_3_11_NC), .out_a_chain(a3_11to3_12), .out_b(b3_11to4_11), .out_b0(b3_11to4_11_ping), .out_b1(b3_11to4_11_pong), .out_c(matrixC3_11), .b_data_valid_ping(b_data_valid_ping_delay3_11), .b_data_valid_pong(b_data_valid_pong_delay3_11), .mode(1'b0));
processing_element pe3_12(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay15), .in_a(in_a_3_12_NC),  .in_a_chain(a3_11to3_12), .in_b(b2_12to3_12), .in_c(matrixC2_12), .out_a(out_a_3_12_NC), .out_a_chain(a3_12to3_13), .out_b(b3_12to4_12), .out_b0(b3_12to4_12_ping), .out_b1(b3_12to4_12_pong), .out_c(matrixC3_12), .b_data_valid_ping(b_data_valid_ping_delay3_12), .b_data_valid_pong(b_data_valid_pong_delay3_12), .mode(1'b0));
processing_element pe3_13(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay16), .in_a(in_a_3_13_NC),  .in_a_chain(a3_12to3_13), .in_b(b2_13to3_13), .in_c(matrixC2_13), .out_a(out_a_3_13_NC), .out_a_chain(a3_13to3_14), .out_b(b3_13to4_13), .out_b0(b3_13to4_13_ping), .out_b1(b3_13to4_13_pong), .out_c(matrixC3_13), .b_data_valid_ping(b_data_valid_ping_delay3_13), .b_data_valid_pong(b_data_valid_pong_delay3_13), .mode(1'b0));
processing_element pe3_14(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay17), .in_a(in_a_3_14_NC),  .in_a_chain(a3_13to3_14), .in_b(b2_14to3_14), .in_c(matrixC2_14), .out_a(out_a_3_14_NC), .out_a_chain(a3_14to3_15), .out_b(b3_14to4_14), .out_b0(b3_14to4_14_ping), .out_b1(b3_14to4_14_pong), .out_c(matrixC3_14), .b_data_valid_ping(b_data_valid_ping_delay3_14), .b_data_valid_pong(b_data_valid_pong_delay3_14), .mode(1'b0));
processing_element pe3_15(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay18), .in_a(in_a_3_15_NC),  .in_a_chain(a3_14to3_15), .in_b(b2_15to3_15), .in_c(matrixC2_15), .out_a(out_a_3_15_NC), .out_a_chain(a3_15to3_16), .out_b(b3_15to4_15), .out_b0(b3_15to4_15_ping), .out_b1(b3_15to4_15_pong), .out_c(matrixC3_15), .b_data_valid_ping(b_data_valid_ping_delay3_15), .b_data_valid_pong(b_data_valid_pong_delay3_15), .mode(1'b0));
processing_element pe4_0(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay4), .in_a(a4),   .in_a_chain(in_a_chain_4_0_NC),   .in_b(b3_0to4_0), .in_c(matrixC3_0), .out_a(out_a_4_0_NC), .out_a_chain(a4_0to4_1), .out_b(b4_0to5_0), .out_b0(b4_0to5_0_ping), .out_b1(b4_0to5_0_pong), .out_c(matrixC4_0), .b_data_valid_ping(b_data_valid_ping_delay4_0), .b_data_valid_pong(b_data_valid_pong_delay4_0), .mode(1'b1));
processing_element pe4_1(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay5), .in_a(in_a_4_1_NC),  .in_a_chain(a4_0to4_1), .in_b(b3_1to4_1), .in_c(matrixC3_1), .out_a(out_a_4_1_NC), .out_a_chain(a4_1to4_2), .out_b(b4_1to5_1), .out_b0(b4_1to5_1_ping), .out_b1(b4_1to5_1_pong), .out_c(matrixC4_1), .b_data_valid_ping(b_data_valid_ping_delay4_1), .b_data_valid_pong(b_data_valid_pong_delay4_1), .mode(1'b0));
processing_element pe4_2(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay6), .in_a(in_a_4_2_NC),  .in_a_chain(a4_1to4_2), .in_b(b3_2to4_2), .in_c(matrixC3_2), .out_a(out_a_4_2_NC), .out_a_chain(a4_2to4_3), .out_b(b4_2to5_2), .out_b0(b4_2to5_2_ping), .out_b1(b4_2to5_2_pong), .out_c(matrixC4_2), .b_data_valid_ping(b_data_valid_ping_delay4_2), .b_data_valid_pong(b_data_valid_pong_delay4_2), .mode(1'b0));
processing_element pe4_3(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay7), .in_a(in_a_4_3_NC),  .in_a_chain(a4_2to4_3), .in_b(b3_3to4_3), .in_c(matrixC3_3), .out_a(out_a_4_3_NC), .out_a_chain(a4_3to4_4), .out_b(b4_3to5_3), .out_b0(b4_3to5_3_ping), .out_b1(b4_3to5_3_pong), .out_c(matrixC4_3), .b_data_valid_ping(b_data_valid_ping_delay4_3), .b_data_valid_pong(b_data_valid_pong_delay4_3), .mode(1'b0));
processing_element pe4_4(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay8), .in_a(in_a_4_4_NC),  .in_a_chain(a4_3to4_4), .in_b(b3_4to4_4), .in_c(matrixC3_4), .out_a(out_a_4_4_NC), .out_a_chain(a4_4to4_5), .out_b(b4_4to5_4), .out_b0(b4_4to5_4_ping), .out_b1(b4_4to5_4_pong), .out_c(matrixC4_4), .b_data_valid_ping(b_data_valid_ping_delay4_4), .b_data_valid_pong(b_data_valid_pong_delay4_4), .mode(1'b0));
processing_element pe4_5(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay9), .in_a(in_a_4_5_NC),  .in_a_chain(a4_4to4_5), .in_b(b3_5to4_5), .in_c(matrixC3_5), .out_a(out_a_4_5_NC), .out_a_chain(a4_5to4_6), .out_b(b4_5to5_5), .out_b0(b4_5to5_5_ping), .out_b1(b4_5to5_5_pong), .out_c(matrixC4_5), .b_data_valid_ping(b_data_valid_ping_delay4_5), .b_data_valid_pong(b_data_valid_pong_delay4_5), .mode(1'b0));
processing_element pe4_6(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay10), .in_a(in_a_4_6_NC),  .in_a_chain(a4_5to4_6), .in_b(b3_6to4_6), .in_c(matrixC3_6), .out_a(out_a_4_6_NC), .out_a_chain(a4_6to4_7), .out_b(b4_6to5_6), .out_b0(b4_6to5_6_ping), .out_b1(b4_6to5_6_pong), .out_c(matrixC4_6), .b_data_valid_ping(b_data_valid_ping_delay4_6), .b_data_valid_pong(b_data_valid_pong_delay4_6), .mode(1'b0));
processing_element pe4_7(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay11), .in_a(in_a_4_7_NC),  .in_a_chain(a4_6to4_7), .in_b(b3_7to4_7), .in_c(matrixC3_7), .out_a(out_a_4_7_NC), .out_a_chain(a4_7to4_8), .out_b(b4_7to5_7), .out_b0(b4_7to5_7_ping), .out_b1(b4_7to5_7_pong), .out_c(matrixC4_7), .b_data_valid_ping(b_data_valid_ping_delay4_7), .b_data_valid_pong(b_data_valid_pong_delay4_7), .mode(1'b0));
processing_element pe4_8(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay12), .in_a(in_a_4_8_NC),  .in_a_chain(a4_7to4_8), .in_b(b3_8to4_8), .in_c(matrixC3_8), .out_a(out_a_4_8_NC), .out_a_chain(a4_8to4_9), .out_b(b4_8to5_8), .out_b0(b4_8to5_8_ping), .out_b1(b4_8to5_8_pong), .out_c(matrixC4_8), .b_data_valid_ping(b_data_valid_ping_delay4_8), .b_data_valid_pong(b_data_valid_pong_delay4_8), .mode(1'b0));
processing_element pe4_9(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay13), .in_a(in_a_4_9_NC),  .in_a_chain(a4_8to4_9), .in_b(b3_9to4_9), .in_c(matrixC3_9), .out_a(out_a_4_9_NC), .out_a_chain(a4_9to4_10), .out_b(b4_9to5_9), .out_b0(b4_9to5_9_ping), .out_b1(b4_9to5_9_pong), .out_c(matrixC4_9), .b_data_valid_ping(b_data_valid_ping_delay4_9), .b_data_valid_pong(b_data_valid_pong_delay4_9), .mode(1'b0));
processing_element pe4_10(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay14), .in_a(in_a_4_10_NC),  .in_a_chain(a4_9to4_10), .in_b(b3_10to4_10), .in_c(matrixC3_10), .out_a(out_a_4_10_NC), .out_a_chain(a4_10to4_11), .out_b(b4_10to5_10), .out_b0(b4_10to5_10_ping), .out_b1(b4_10to5_10_pong), .out_c(matrixC4_10), .b_data_valid_ping(b_data_valid_ping_delay4_10), .b_data_valid_pong(b_data_valid_pong_delay4_10), .mode(1'b0));
processing_element pe4_11(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay15), .in_a(in_a_4_11_NC),  .in_a_chain(a4_10to4_11), .in_b(b3_11to4_11), .in_c(matrixC3_11), .out_a(out_a_4_11_NC), .out_a_chain(a4_11to4_12), .out_b(b4_11to5_11), .out_b0(b4_11to5_11_ping), .out_b1(b4_11to5_11_pong), .out_c(matrixC4_11), .b_data_valid_ping(b_data_valid_ping_delay4_11), .b_data_valid_pong(b_data_valid_pong_delay4_11), .mode(1'b0));
processing_element pe4_12(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay16), .in_a(in_a_4_12_NC),  .in_a_chain(a4_11to4_12), .in_b(b3_12to4_12), .in_c(matrixC3_12), .out_a(out_a_4_12_NC), .out_a_chain(a4_12to4_13), .out_b(b4_12to5_12), .out_b0(b4_12to5_12_ping), .out_b1(b4_12to5_12_pong), .out_c(matrixC4_12), .b_data_valid_ping(b_data_valid_ping_delay4_12), .b_data_valid_pong(b_data_valid_pong_delay4_12), .mode(1'b0));
processing_element pe4_13(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay17), .in_a(in_a_4_13_NC),  .in_a_chain(a4_12to4_13), .in_b(b3_13to4_13), .in_c(matrixC3_13), .out_a(out_a_4_13_NC), .out_a_chain(a4_13to4_14), .out_b(b4_13to5_13), .out_b0(b4_13to5_13_ping), .out_b1(b4_13to5_13_pong), .out_c(matrixC4_13), .b_data_valid_ping(b_data_valid_ping_delay4_13), .b_data_valid_pong(b_data_valid_pong_delay4_13), .mode(1'b0));
processing_element pe4_14(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay18), .in_a(in_a_4_14_NC),  .in_a_chain(a4_13to4_14), .in_b(b3_14to4_14), .in_c(matrixC3_14), .out_a(out_a_4_14_NC), .out_a_chain(a4_14to4_15), .out_b(b4_14to5_14), .out_b0(b4_14to5_14_ping), .out_b1(b4_14to5_14_pong), .out_c(matrixC4_14), .b_data_valid_ping(b_data_valid_ping_delay4_14), .b_data_valid_pong(b_data_valid_pong_delay4_14), .mode(1'b0));
processing_element pe4_15(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay19), .in_a(in_a_4_15_NC),  .in_a_chain(a4_14to4_15), .in_b(b3_15to4_15), .in_c(matrixC3_15), .out_a(out_a_4_15_NC), .out_a_chain(a4_15to4_16), .out_b(b4_15to5_15), .out_b0(b4_15to5_15_ping), .out_b1(b4_15to5_15_pong), .out_c(matrixC4_15), .b_data_valid_ping(b_data_valid_ping_delay4_15), .b_data_valid_pong(b_data_valid_pong_delay4_15), .mode(1'b0));
processing_element pe5_0(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay5), .in_a(a5),   .in_a_chain(in_a_chain_5_0_NC),   .in_b(b4_0to5_0), .in_c(matrixC4_0), .out_a(out_a_5_0_NC), .out_a_chain(a5_0to5_1), .out_b(b5_0to6_0), .out_b0(b5_0to6_0_ping), .out_b1(b5_0to6_0_pong), .out_c(matrixC5_0), .b_data_valid_ping(b_data_valid_ping_delay5_0), .b_data_valid_pong(b_data_valid_pong_delay5_0), .mode(1'b1));
processing_element pe5_1(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay6), .in_a(in_a_5_1_NC),  .in_a_chain(a5_0to5_1), .in_b(b4_1to5_1), .in_c(matrixC4_1), .out_a(out_a_5_1_NC), .out_a_chain(a5_1to5_2), .out_b(b5_1to6_1), .out_b0(b5_1to6_1_ping), .out_b1(b5_1to6_1_pong), .out_c(matrixC5_1), .b_data_valid_ping(b_data_valid_ping_delay5_1), .b_data_valid_pong(b_data_valid_pong_delay5_1), .mode(1'b0));
processing_element pe5_2(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay7), .in_a(in_a_5_2_NC),  .in_a_chain(a5_1to5_2), .in_b(b4_2to5_2), .in_c(matrixC4_2), .out_a(out_a_5_2_NC), .out_a_chain(a5_2to5_3), .out_b(b5_2to6_2), .out_b0(b5_2to6_2_ping), .out_b1(b5_2to6_2_pong), .out_c(matrixC5_2), .b_data_valid_ping(b_data_valid_ping_delay5_2), .b_data_valid_pong(b_data_valid_pong_delay5_2), .mode(1'b0));
processing_element pe5_3(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay8), .in_a(in_a_5_3_NC),  .in_a_chain(a5_2to5_3), .in_b(b4_3to5_3), .in_c(matrixC4_3), .out_a(out_a_5_3_NC), .out_a_chain(a5_3to5_4), .out_b(b5_3to6_3), .out_b0(b5_3to6_3_ping), .out_b1(b5_3to6_3_pong), .out_c(matrixC5_3), .b_data_valid_ping(b_data_valid_ping_delay5_3), .b_data_valid_pong(b_data_valid_pong_delay5_3), .mode(1'b0));
processing_element pe5_4(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay9), .in_a(in_a_5_4_NC),  .in_a_chain(a5_3to5_4), .in_b(b4_4to5_4), .in_c(matrixC4_4), .out_a(out_a_5_4_NC), .out_a_chain(a5_4to5_5), .out_b(b5_4to6_4), .out_b0(b5_4to6_4_ping), .out_b1(b5_4to6_4_pong), .out_c(matrixC5_4), .b_data_valid_ping(b_data_valid_ping_delay5_4), .b_data_valid_pong(b_data_valid_pong_delay5_4), .mode(1'b0));
processing_element pe5_5(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay10), .in_a(in_a_5_5_NC),  .in_a_chain(a5_4to5_5), .in_b(b4_5to5_5), .in_c(matrixC4_5), .out_a(out_a_5_5_NC), .out_a_chain(a5_5to5_6), .out_b(b5_5to6_5), .out_b0(b5_5to6_5_ping), .out_b1(b5_5to6_5_pong), .out_c(matrixC5_5), .b_data_valid_ping(b_data_valid_ping_delay5_5), .b_data_valid_pong(b_data_valid_pong_delay5_5), .mode(1'b0));
processing_element pe5_6(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay11), .in_a(in_a_5_6_NC),  .in_a_chain(a5_5to5_6), .in_b(b4_6to5_6), .in_c(matrixC4_6), .out_a(out_a_5_6_NC), .out_a_chain(a5_6to5_7), .out_b(b5_6to6_6), .out_b0(b5_6to6_6_ping), .out_b1(b5_6to6_6_pong), .out_c(matrixC5_6), .b_data_valid_ping(b_data_valid_ping_delay5_6), .b_data_valid_pong(b_data_valid_pong_delay5_6), .mode(1'b0));
processing_element pe5_7(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay12), .in_a(in_a_5_7_NC),  .in_a_chain(a5_6to5_7), .in_b(b4_7to5_7), .in_c(matrixC4_7), .out_a(out_a_5_7_NC), .out_a_chain(a5_7to5_8), .out_b(b5_7to6_7), .out_b0(b5_7to6_7_ping), .out_b1(b5_7to6_7_pong), .out_c(matrixC5_7), .b_data_valid_ping(b_data_valid_ping_delay5_7), .b_data_valid_pong(b_data_valid_pong_delay5_7), .mode(1'b0));
processing_element pe5_8(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay13), .in_a(in_a_5_8_NC),  .in_a_chain(a5_7to5_8), .in_b(b4_8to5_8), .in_c(matrixC4_8), .out_a(out_a_5_8_NC), .out_a_chain(a5_8to5_9), .out_b(b5_8to6_8), .out_b0(b5_8to6_8_ping), .out_b1(b5_8to6_8_pong), .out_c(matrixC5_8), .b_data_valid_ping(b_data_valid_ping_delay5_8), .b_data_valid_pong(b_data_valid_pong_delay5_8), .mode(1'b0));
processing_element pe5_9(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay14), .in_a(in_a_5_9_NC),  .in_a_chain(a5_8to5_9), .in_b(b4_9to5_9), .in_c(matrixC4_9), .out_a(out_a_5_9_NC), .out_a_chain(a5_9to5_10), .out_b(b5_9to6_9), .out_b0(b5_9to6_9_ping), .out_b1(b5_9to6_9_pong), .out_c(matrixC5_9), .b_data_valid_ping(b_data_valid_ping_delay5_9), .b_data_valid_pong(b_data_valid_pong_delay5_9), .mode(1'b0));
processing_element pe5_10(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay15), .in_a(in_a_5_10_NC),  .in_a_chain(a5_9to5_10), .in_b(b4_10to5_10), .in_c(matrixC4_10), .out_a(out_a_5_10_NC), .out_a_chain(a5_10to5_11), .out_b(b5_10to6_10), .out_b0(b5_10to6_10_ping), .out_b1(b5_10to6_10_pong), .out_c(matrixC5_10), .b_data_valid_ping(b_data_valid_ping_delay5_10), .b_data_valid_pong(b_data_valid_pong_delay5_10), .mode(1'b0));
processing_element pe5_11(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay16), .in_a(in_a_5_11_NC),  .in_a_chain(a5_10to5_11), .in_b(b4_11to5_11), .in_c(matrixC4_11), .out_a(out_a_5_11_NC), .out_a_chain(a5_11to5_12), .out_b(b5_11to6_11), .out_b0(b5_11to6_11_ping), .out_b1(b5_11to6_11_pong), .out_c(matrixC5_11), .b_data_valid_ping(b_data_valid_ping_delay5_11), .b_data_valid_pong(b_data_valid_pong_delay5_11), .mode(1'b0));
processing_element pe5_12(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay17), .in_a(in_a_5_12_NC),  .in_a_chain(a5_11to5_12), .in_b(b4_12to5_12), .in_c(matrixC4_12), .out_a(out_a_5_12_NC), .out_a_chain(a5_12to5_13), .out_b(b5_12to6_12), .out_b0(b5_12to6_12_ping), .out_b1(b5_12to6_12_pong), .out_c(matrixC5_12), .b_data_valid_ping(b_data_valid_ping_delay5_12), .b_data_valid_pong(b_data_valid_pong_delay5_12), .mode(1'b0));
processing_element pe5_13(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay18), .in_a(in_a_5_13_NC),  .in_a_chain(a5_12to5_13), .in_b(b4_13to5_13), .in_c(matrixC4_13), .out_a(out_a_5_13_NC), .out_a_chain(a5_13to5_14), .out_b(b5_13to6_13), .out_b0(b5_13to6_13_ping), .out_b1(b5_13to6_13_pong), .out_c(matrixC5_13), .b_data_valid_ping(b_data_valid_ping_delay5_13), .b_data_valid_pong(b_data_valid_pong_delay5_13), .mode(1'b0));
processing_element pe5_14(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay19), .in_a(in_a_5_14_NC),  .in_a_chain(a5_13to5_14), .in_b(b4_14to5_14), .in_c(matrixC4_14), .out_a(out_a_5_14_NC), .out_a_chain(a5_14to5_15), .out_b(b5_14to6_14), .out_b0(b5_14to6_14_ping), .out_b1(b5_14to6_14_pong), .out_c(matrixC5_14), .b_data_valid_ping(b_data_valid_ping_delay5_14), .b_data_valid_pong(b_data_valid_pong_delay5_14), .mode(1'b0));
processing_element pe5_15(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay20), .in_a(in_a_5_15_NC),  .in_a_chain(a5_14to5_15), .in_b(b4_15to5_15), .in_c(matrixC4_15), .out_a(out_a_5_15_NC), .out_a_chain(a5_15to5_16), .out_b(b5_15to6_15), .out_b0(b5_15to6_15_ping), .out_b1(b5_15to6_15_pong), .out_c(matrixC5_15), .b_data_valid_ping(b_data_valid_ping_delay5_15), .b_data_valid_pong(b_data_valid_pong_delay5_15), .mode(1'b0));
processing_element pe6_0(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay6), .in_a(a6),   .in_a_chain(in_a_chain_6_0_NC),   .in_b(b5_0to6_0), .in_c(matrixC5_0), .out_a(out_a_6_0_NC), .out_a_chain(a6_0to6_1), .out_b(b6_0to7_0), .out_b0(b6_0to7_0_ping), .out_b1(b6_0to7_0_pong), .out_c(matrixC6_0), .b_data_valid_ping(b_data_valid_ping_delay6_0), .b_data_valid_pong(b_data_valid_pong_delay6_0), .mode(1'b1));
processing_element pe6_1(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay7), .in_a(in_a_6_1_NC),  .in_a_chain(a6_0to6_1), .in_b(b5_1to6_1), .in_c(matrixC5_1), .out_a(out_a_6_1_NC), .out_a_chain(a6_1to6_2), .out_b(b6_1to7_1), .out_b0(b6_1to7_1_ping), .out_b1(b6_1to7_1_pong), .out_c(matrixC6_1), .b_data_valid_ping(b_data_valid_ping_delay6_1), .b_data_valid_pong(b_data_valid_pong_delay6_1), .mode(1'b0));
processing_element pe6_2(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay8), .in_a(in_a_6_2_NC),  .in_a_chain(a6_1to6_2), .in_b(b5_2to6_2), .in_c(matrixC5_2), .out_a(out_a_6_2_NC), .out_a_chain(a6_2to6_3), .out_b(b6_2to7_2), .out_b0(b6_2to7_2_ping), .out_b1(b6_2to7_2_pong), .out_c(matrixC6_2), .b_data_valid_ping(b_data_valid_ping_delay6_2), .b_data_valid_pong(b_data_valid_pong_delay6_2), .mode(1'b0));
processing_element pe6_3(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay9), .in_a(in_a_6_3_NC),  .in_a_chain(a6_2to6_3), .in_b(b5_3to6_3), .in_c(matrixC5_3), .out_a(out_a_6_3_NC), .out_a_chain(a6_3to6_4), .out_b(b6_3to7_3), .out_b0(b6_3to7_3_ping), .out_b1(b6_3to7_3_pong), .out_c(matrixC6_3), .b_data_valid_ping(b_data_valid_ping_delay6_3), .b_data_valid_pong(b_data_valid_pong_delay6_3), .mode(1'b0));
processing_element pe6_4(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay10), .in_a(in_a_6_4_NC),  .in_a_chain(a6_3to6_4), .in_b(b5_4to6_4), .in_c(matrixC5_4), .out_a(out_a_6_4_NC), .out_a_chain(a6_4to6_5), .out_b(b6_4to7_4), .out_b0(b6_4to7_4_ping), .out_b1(b6_4to7_4_pong), .out_c(matrixC6_4), .b_data_valid_ping(b_data_valid_ping_delay6_4), .b_data_valid_pong(b_data_valid_pong_delay6_4), .mode(1'b0));
processing_element pe6_5(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay11), .in_a(in_a_6_5_NC),  .in_a_chain(a6_4to6_5), .in_b(b5_5to6_5), .in_c(matrixC5_5), .out_a(out_a_6_5_NC), .out_a_chain(a6_5to6_6), .out_b(b6_5to7_5), .out_b0(b6_5to7_5_ping), .out_b1(b6_5to7_5_pong), .out_c(matrixC6_5), .b_data_valid_ping(b_data_valid_ping_delay6_5), .b_data_valid_pong(b_data_valid_pong_delay6_5), .mode(1'b0));
processing_element pe6_6(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay12), .in_a(in_a_6_6_NC),  .in_a_chain(a6_5to6_6), .in_b(b5_6to6_6), .in_c(matrixC5_6), .out_a(out_a_6_6_NC), .out_a_chain(a6_6to6_7), .out_b(b6_6to7_6), .out_b0(b6_6to7_6_ping), .out_b1(b6_6to7_6_pong), .out_c(matrixC6_6), .b_data_valid_ping(b_data_valid_ping_delay6_6), .b_data_valid_pong(b_data_valid_pong_delay6_6), .mode(1'b0));
processing_element pe6_7(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay13), .in_a(in_a_6_7_NC),  .in_a_chain(a6_6to6_7), .in_b(b5_7to6_7), .in_c(matrixC5_7), .out_a(out_a_6_7_NC), .out_a_chain(a6_7to6_8), .out_b(b6_7to7_7), .out_b0(b6_7to7_7_ping), .out_b1(b6_7to7_7_pong), .out_c(matrixC6_7), .b_data_valid_ping(b_data_valid_ping_delay6_7), .b_data_valid_pong(b_data_valid_pong_delay6_7), .mode(1'b0));
processing_element pe6_8(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay14), .in_a(in_a_6_8_NC),  .in_a_chain(a6_7to6_8), .in_b(b5_8to6_8), .in_c(matrixC5_8), .out_a(out_a_6_8_NC), .out_a_chain(a6_8to6_9), .out_b(b6_8to7_8), .out_b0(b6_8to7_8_ping), .out_b1(b6_8to7_8_pong), .out_c(matrixC6_8), .b_data_valid_ping(b_data_valid_ping_delay6_8), .b_data_valid_pong(b_data_valid_pong_delay6_8), .mode(1'b0));
processing_element pe6_9(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay15), .in_a(in_a_6_9_NC),  .in_a_chain(a6_8to6_9), .in_b(b5_9to6_9), .in_c(matrixC5_9), .out_a(out_a_6_9_NC), .out_a_chain(a6_9to6_10), .out_b(b6_9to7_9), .out_b0(b6_9to7_9_ping), .out_b1(b6_9to7_9_pong), .out_c(matrixC6_9), .b_data_valid_ping(b_data_valid_ping_delay6_9), .b_data_valid_pong(b_data_valid_pong_delay6_9), .mode(1'b0));
processing_element pe6_10(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay16), .in_a(in_a_6_10_NC),  .in_a_chain(a6_9to6_10), .in_b(b5_10to6_10), .in_c(matrixC5_10), .out_a(out_a_6_10_NC), .out_a_chain(a6_10to6_11), .out_b(b6_10to7_10), .out_b0(b6_10to7_10_ping), .out_b1(b6_10to7_10_pong), .out_c(matrixC6_10), .b_data_valid_ping(b_data_valid_ping_delay6_10), .b_data_valid_pong(b_data_valid_pong_delay6_10), .mode(1'b0));
processing_element pe6_11(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay17), .in_a(in_a_6_11_NC),  .in_a_chain(a6_10to6_11), .in_b(b5_11to6_11), .in_c(matrixC5_11), .out_a(out_a_6_11_NC), .out_a_chain(a6_11to6_12), .out_b(b6_11to7_11), .out_b0(b6_11to7_11_ping), .out_b1(b6_11to7_11_pong), .out_c(matrixC6_11), .b_data_valid_ping(b_data_valid_ping_delay6_11), .b_data_valid_pong(b_data_valid_pong_delay6_11), .mode(1'b0));
processing_element pe6_12(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay18), .in_a(in_a_6_12_NC),  .in_a_chain(a6_11to6_12), .in_b(b5_12to6_12), .in_c(matrixC5_12), .out_a(out_a_6_12_NC), .out_a_chain(a6_12to6_13), .out_b(b6_12to7_12), .out_b0(b6_12to7_12_ping), .out_b1(b6_12to7_12_pong), .out_c(matrixC6_12), .b_data_valid_ping(b_data_valid_ping_delay6_12), .b_data_valid_pong(b_data_valid_pong_delay6_12), .mode(1'b0));
processing_element pe6_13(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay19), .in_a(in_a_6_13_NC),  .in_a_chain(a6_12to6_13), .in_b(b5_13to6_13), .in_c(matrixC5_13), .out_a(out_a_6_13_NC), .out_a_chain(a6_13to6_14), .out_b(b6_13to7_13), .out_b0(b6_13to7_13_ping), .out_b1(b6_13to7_13_pong), .out_c(matrixC6_13), .b_data_valid_ping(b_data_valid_ping_delay6_13), .b_data_valid_pong(b_data_valid_pong_delay6_13), .mode(1'b0));
processing_element pe6_14(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay20), .in_a(in_a_6_14_NC),  .in_a_chain(a6_13to6_14), .in_b(b5_14to6_14), .in_c(matrixC5_14), .out_a(out_a_6_14_NC), .out_a_chain(a6_14to6_15), .out_b(b6_14to7_14), .out_b0(b6_14to7_14_ping), .out_b1(b6_14to7_14_pong), .out_c(matrixC6_14), .b_data_valid_ping(b_data_valid_ping_delay6_14), .b_data_valid_pong(b_data_valid_pong_delay6_14), .mode(1'b0));
processing_element pe6_15(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay21), .in_a(in_a_6_15_NC),  .in_a_chain(a6_14to6_15), .in_b(b5_15to6_15), .in_c(matrixC5_15), .out_a(out_a_6_15_NC), .out_a_chain(a6_15to6_16), .out_b(b6_15to7_15), .out_b0(b6_15to7_15_ping), .out_b1(b6_15to7_15_pong), .out_c(matrixC6_15), .b_data_valid_ping(b_data_valid_ping_delay6_15), .b_data_valid_pong(b_data_valid_pong_delay6_15), .mode(1'b0));
processing_element pe7_0(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay7), .in_a(a7),   .in_a_chain(in_a_chain_7_0_NC),   .in_b(b6_0to7_0), .in_c(matrixC6_0), .out_a(out_a_7_0_NC), .out_a_chain(a7_0to7_1), .out_b(b7_0to8_0), .out_b0(b7_0to8_0_ping), .out_b1(b7_0to8_0_pong), .out_c(matrixC7_0), .b_data_valid_ping(b_data_valid_ping_delay7_0), .b_data_valid_pong(b_data_valid_pong_delay7_0), .mode(1'b1));
processing_element pe7_1(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay8), .in_a(in_a_7_1_NC),  .in_a_chain(a7_0to7_1), .in_b(b6_1to7_1), .in_c(matrixC6_1), .out_a(out_a_7_1_NC), .out_a_chain(a7_1to7_2), .out_b(b7_1to8_1), .out_b0(b7_1to8_1_ping), .out_b1(b7_1to8_1_pong), .out_c(matrixC7_1), .b_data_valid_ping(b_data_valid_ping_delay7_1), .b_data_valid_pong(b_data_valid_pong_delay7_1), .mode(1'b0));
processing_element pe7_2(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay9), .in_a(in_a_7_2_NC),  .in_a_chain(a7_1to7_2), .in_b(b6_2to7_2), .in_c(matrixC6_2), .out_a(out_a_7_2_NC), .out_a_chain(a7_2to7_3), .out_b(b7_2to8_2), .out_b0(b7_2to8_2_ping), .out_b1(b7_2to8_2_pong), .out_c(matrixC7_2), .b_data_valid_ping(b_data_valid_ping_delay7_2), .b_data_valid_pong(b_data_valid_pong_delay7_2), .mode(1'b0));
processing_element pe7_3(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay10), .in_a(in_a_7_3_NC),  .in_a_chain(a7_2to7_3), .in_b(b6_3to7_3), .in_c(matrixC6_3), .out_a(out_a_7_3_NC), .out_a_chain(a7_3to7_4), .out_b(b7_3to8_3), .out_b0(b7_3to8_3_ping), .out_b1(b7_3to8_3_pong), .out_c(matrixC7_3), .b_data_valid_ping(b_data_valid_ping_delay7_3), .b_data_valid_pong(b_data_valid_pong_delay7_3), .mode(1'b0));
processing_element pe7_4(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay11), .in_a(in_a_7_4_NC),  .in_a_chain(a7_3to7_4), .in_b(b6_4to7_4), .in_c(matrixC6_4), .out_a(out_a_7_4_NC), .out_a_chain(a7_4to7_5), .out_b(b7_4to8_4), .out_b0(b7_4to8_4_ping), .out_b1(b7_4to8_4_pong), .out_c(matrixC7_4), .b_data_valid_ping(b_data_valid_ping_delay7_4), .b_data_valid_pong(b_data_valid_pong_delay7_4), .mode(1'b0));
processing_element pe7_5(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay12), .in_a(in_a_7_5_NC),  .in_a_chain(a7_4to7_5), .in_b(b6_5to7_5), .in_c(matrixC6_5), .out_a(out_a_7_5_NC), .out_a_chain(a7_5to7_6), .out_b(b7_5to8_5), .out_b0(b7_5to8_5_ping), .out_b1(b7_5to8_5_pong), .out_c(matrixC7_5), .b_data_valid_ping(b_data_valid_ping_delay7_5), .b_data_valid_pong(b_data_valid_pong_delay7_5), .mode(1'b0));
processing_element pe7_6(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay13), .in_a(in_a_7_6_NC),  .in_a_chain(a7_5to7_6), .in_b(b6_6to7_6), .in_c(matrixC6_6), .out_a(out_a_7_6_NC), .out_a_chain(a7_6to7_7), .out_b(b7_6to8_6), .out_b0(b7_6to8_6_ping), .out_b1(b7_6to8_6_pong), .out_c(matrixC7_6), .b_data_valid_ping(b_data_valid_ping_delay7_6), .b_data_valid_pong(b_data_valid_pong_delay7_6), .mode(1'b0));
processing_element pe7_7(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay14), .in_a(in_a_7_7_NC),  .in_a_chain(a7_6to7_7), .in_b(b6_7to7_7), .in_c(matrixC6_7), .out_a(out_a_7_7_NC), .out_a_chain(a7_7to7_8), .out_b(b7_7to8_7), .out_b0(b7_7to8_7_ping), .out_b1(b7_7to8_7_pong), .out_c(matrixC7_7), .b_data_valid_ping(b_data_valid_ping_delay7_7), .b_data_valid_pong(b_data_valid_pong_delay7_7), .mode(1'b0));
processing_element pe7_8(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay15), .in_a(in_a_7_8_NC),  .in_a_chain(a7_7to7_8), .in_b(b6_8to7_8), .in_c(matrixC6_8), .out_a(out_a_7_8_NC), .out_a_chain(a7_8to7_9), .out_b(b7_8to8_8), .out_b0(b7_8to8_8_ping), .out_b1(b7_8to8_8_pong), .out_c(matrixC7_8), .b_data_valid_ping(b_data_valid_ping_delay7_8), .b_data_valid_pong(b_data_valid_pong_delay7_8), .mode(1'b0));
processing_element pe7_9(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay16), .in_a(in_a_7_9_NC),  .in_a_chain(a7_8to7_9), .in_b(b6_9to7_9), .in_c(matrixC6_9), .out_a(out_a_7_9_NC), .out_a_chain(a7_9to7_10), .out_b(b7_9to8_9), .out_b0(b7_9to8_9_ping), .out_b1(b7_9to8_9_pong), .out_c(matrixC7_9), .b_data_valid_ping(b_data_valid_ping_delay7_9), .b_data_valid_pong(b_data_valid_pong_delay7_9), .mode(1'b0));
processing_element pe7_10(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay17), .in_a(in_a_7_10_NC),  .in_a_chain(a7_9to7_10), .in_b(b6_10to7_10), .in_c(matrixC6_10), .out_a(out_a_7_10_NC), .out_a_chain(a7_10to7_11), .out_b(b7_10to8_10), .out_b0(b7_10to8_10_ping), .out_b1(b7_10to8_10_pong), .out_c(matrixC7_10), .b_data_valid_ping(b_data_valid_ping_delay7_10), .b_data_valid_pong(b_data_valid_pong_delay7_10), .mode(1'b0));
processing_element pe7_11(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay18), .in_a(in_a_7_11_NC),  .in_a_chain(a7_10to7_11), .in_b(b6_11to7_11), .in_c(matrixC6_11), .out_a(out_a_7_11_NC), .out_a_chain(a7_11to7_12), .out_b(b7_11to8_11), .out_b0(b7_11to8_11_ping), .out_b1(b7_11to8_11_pong), .out_c(matrixC7_11), .b_data_valid_ping(b_data_valid_ping_delay7_11), .b_data_valid_pong(b_data_valid_pong_delay7_11), .mode(1'b0));
processing_element pe7_12(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay19), .in_a(in_a_7_12_NC),  .in_a_chain(a7_11to7_12), .in_b(b6_12to7_12), .in_c(matrixC6_12), .out_a(out_a_7_12_NC), .out_a_chain(a7_12to7_13), .out_b(b7_12to8_12), .out_b0(b7_12to8_12_ping), .out_b1(b7_12to8_12_pong), .out_c(matrixC7_12), .b_data_valid_ping(b_data_valid_ping_delay7_12), .b_data_valid_pong(b_data_valid_pong_delay7_12), .mode(1'b0));
processing_element pe7_13(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay20), .in_a(in_a_7_13_NC),  .in_a_chain(a7_12to7_13), .in_b(b6_13to7_13), .in_c(matrixC6_13), .out_a(out_a_7_13_NC), .out_a_chain(a7_13to7_14), .out_b(b7_13to8_13), .out_b0(b7_13to8_13_ping), .out_b1(b7_13to8_13_pong), .out_c(matrixC7_13), .b_data_valid_ping(b_data_valid_ping_delay7_13), .b_data_valid_pong(b_data_valid_pong_delay7_13), .mode(1'b0));
processing_element pe7_14(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay21), .in_a(in_a_7_14_NC),  .in_a_chain(a7_13to7_14), .in_b(b6_14to7_14), .in_c(matrixC6_14), .out_a(out_a_7_14_NC), .out_a_chain(a7_14to7_15), .out_b(b7_14to8_14), .out_b0(b7_14to8_14_ping), .out_b1(b7_14to8_14_pong), .out_c(matrixC7_14), .b_data_valid_ping(b_data_valid_ping_delay7_14), .b_data_valid_pong(b_data_valid_pong_delay7_14), .mode(1'b0));
processing_element pe7_15(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay22), .in_a(in_a_7_15_NC),  .in_a_chain(a7_14to7_15), .in_b(b6_15to7_15), .in_c(matrixC6_15), .out_a(out_a_7_15_NC), .out_a_chain(a7_15to7_16), .out_b(b7_15to8_15), .out_b0(b7_15to8_15_ping), .out_b1(b7_15to8_15_pong), .out_c(matrixC7_15), .b_data_valid_ping(b_data_valid_ping_delay7_15), .b_data_valid_pong(b_data_valid_pong_delay7_15), .mode(1'b0));
processing_element pe8_0(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay8), .in_a(a8),   .in_a_chain(in_a_chain_8_0_NC),   .in_b(b7_0to8_0), .in_c(matrixC7_0), .out_a(out_a_8_0_NC), .out_a_chain(a8_0to8_1), .out_b(b8_0to9_0), .out_b0(b8_0to9_0_ping), .out_b1(b8_0to9_0_pong), .out_c(matrixC8_0), .b_data_valid_ping(b_data_valid_ping_delay8_0), .b_data_valid_pong(b_data_valid_pong_delay8_0), .mode(1'b1));
processing_element pe8_1(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay9), .in_a(in_a_8_1_NC),  .in_a_chain(a8_0to8_1), .in_b(b7_1to8_1), .in_c(matrixC7_1), .out_a(out_a_8_1_NC), .out_a_chain(a8_1to8_2), .out_b(b8_1to9_1), .out_b0(b8_1to9_1_ping), .out_b1(b8_1to9_1_pong), .out_c(matrixC8_1), .b_data_valid_ping(b_data_valid_ping_delay8_1), .b_data_valid_pong(b_data_valid_pong_delay8_1), .mode(1'b0));
processing_element pe8_2(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay10), .in_a(in_a_8_2_NC),  .in_a_chain(a8_1to8_2), .in_b(b7_2to8_2), .in_c(matrixC7_2), .out_a(out_a_8_2_NC), .out_a_chain(a8_2to8_3), .out_b(b8_2to9_2), .out_b0(b8_2to9_2_ping), .out_b1(b8_2to9_2_pong), .out_c(matrixC8_2), .b_data_valid_ping(b_data_valid_ping_delay8_2), .b_data_valid_pong(b_data_valid_pong_delay8_2), .mode(1'b0));
processing_element pe8_3(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay11), .in_a(in_a_8_3_NC),  .in_a_chain(a8_2to8_3), .in_b(b7_3to8_3), .in_c(matrixC7_3), .out_a(out_a_8_3_NC), .out_a_chain(a8_3to8_4), .out_b(b8_3to9_3), .out_b0(b8_3to9_3_ping), .out_b1(b8_3to9_3_pong), .out_c(matrixC8_3), .b_data_valid_ping(b_data_valid_ping_delay8_3), .b_data_valid_pong(b_data_valid_pong_delay8_3), .mode(1'b0));
processing_element pe8_4(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay12), .in_a(in_a_8_4_NC),  .in_a_chain(a8_3to8_4), .in_b(b7_4to8_4), .in_c(matrixC7_4), .out_a(out_a_8_4_NC), .out_a_chain(a8_4to8_5), .out_b(b8_4to9_4), .out_b0(b8_4to9_4_ping), .out_b1(b8_4to9_4_pong), .out_c(matrixC8_4), .b_data_valid_ping(b_data_valid_ping_delay8_4), .b_data_valid_pong(b_data_valid_pong_delay8_4), .mode(1'b0));
processing_element pe8_5(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay13), .in_a(in_a_8_5_NC),  .in_a_chain(a8_4to8_5), .in_b(b7_5to8_5), .in_c(matrixC7_5), .out_a(out_a_8_5_NC), .out_a_chain(a8_5to8_6), .out_b(b8_5to9_5), .out_b0(b8_5to9_5_ping), .out_b1(b8_5to9_5_pong), .out_c(matrixC8_5), .b_data_valid_ping(b_data_valid_ping_delay8_5), .b_data_valid_pong(b_data_valid_pong_delay8_5), .mode(1'b0));
processing_element pe8_6(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay14), .in_a(in_a_8_6_NC),  .in_a_chain(a8_5to8_6), .in_b(b7_6to8_6), .in_c(matrixC7_6), .out_a(out_a_8_6_NC), .out_a_chain(a8_6to8_7), .out_b(b8_6to9_6), .out_b0(b8_6to9_6_ping), .out_b1(b8_6to9_6_pong), .out_c(matrixC8_6), .b_data_valid_ping(b_data_valid_ping_delay8_6), .b_data_valid_pong(b_data_valid_pong_delay8_6), .mode(1'b0));
processing_element pe8_7(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay15), .in_a(in_a_8_7_NC),  .in_a_chain(a8_6to8_7), .in_b(b7_7to8_7), .in_c(matrixC7_7), .out_a(out_a_8_7_NC), .out_a_chain(a8_7to8_8), .out_b(b8_7to9_7), .out_b0(b8_7to9_7_ping), .out_b1(b8_7to9_7_pong), .out_c(matrixC8_7), .b_data_valid_ping(b_data_valid_ping_delay8_7), .b_data_valid_pong(b_data_valid_pong_delay8_7), .mode(1'b0));
processing_element pe8_8(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay16), .in_a(in_a_8_8_NC),  .in_a_chain(a8_7to8_8), .in_b(b7_8to8_8), .in_c(matrixC7_8), .out_a(out_a_8_8_NC), .out_a_chain(a8_8to8_9), .out_b(b8_8to9_8), .out_b0(b8_8to9_8_ping), .out_b1(b8_8to9_8_pong), .out_c(matrixC8_8), .b_data_valid_ping(b_data_valid_ping_delay8_8), .b_data_valid_pong(b_data_valid_pong_delay8_8), .mode(1'b0));
processing_element pe8_9(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay17), .in_a(in_a_8_9_NC),  .in_a_chain(a8_8to8_9), .in_b(b7_9to8_9), .in_c(matrixC7_9), .out_a(out_a_8_9_NC), .out_a_chain(a8_9to8_10), .out_b(b8_9to9_9), .out_b0(b8_9to9_9_ping), .out_b1(b8_9to9_9_pong), .out_c(matrixC8_9), .b_data_valid_ping(b_data_valid_ping_delay8_9), .b_data_valid_pong(b_data_valid_pong_delay8_9), .mode(1'b0));
processing_element pe8_10(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay18), .in_a(in_a_8_10_NC),  .in_a_chain(a8_9to8_10), .in_b(b7_10to8_10), .in_c(matrixC7_10), .out_a(out_a_8_10_NC), .out_a_chain(a8_10to8_11), .out_b(b8_10to9_10), .out_b0(b8_10to9_10_ping), .out_b1(b8_10to9_10_pong), .out_c(matrixC8_10), .b_data_valid_ping(b_data_valid_ping_delay8_10), .b_data_valid_pong(b_data_valid_pong_delay8_10), .mode(1'b0));
processing_element pe8_11(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay19), .in_a(in_a_8_11_NC),  .in_a_chain(a8_10to8_11), .in_b(b7_11to8_11), .in_c(matrixC7_11), .out_a(out_a_8_11_NC), .out_a_chain(a8_11to8_12), .out_b(b8_11to9_11), .out_b0(b8_11to9_11_ping), .out_b1(b8_11to9_11_pong), .out_c(matrixC8_11), .b_data_valid_ping(b_data_valid_ping_delay8_11), .b_data_valid_pong(b_data_valid_pong_delay8_11), .mode(1'b0));
processing_element pe8_12(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay20), .in_a(in_a_8_12_NC),  .in_a_chain(a8_11to8_12), .in_b(b7_12to8_12), .in_c(matrixC7_12), .out_a(out_a_8_12_NC), .out_a_chain(a8_12to8_13), .out_b(b8_12to9_12), .out_b0(b8_12to9_12_ping), .out_b1(b8_12to9_12_pong), .out_c(matrixC8_12), .b_data_valid_ping(b_data_valid_ping_delay8_12), .b_data_valid_pong(b_data_valid_pong_delay8_12), .mode(1'b0));
processing_element pe8_13(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay21), .in_a(in_a_8_13_NC),  .in_a_chain(a8_12to8_13), .in_b(b7_13to8_13), .in_c(matrixC7_13), .out_a(out_a_8_13_NC), .out_a_chain(a8_13to8_14), .out_b(b8_13to9_13), .out_b0(b8_13to9_13_ping), .out_b1(b8_13to9_13_pong), .out_c(matrixC8_13), .b_data_valid_ping(b_data_valid_ping_delay8_13), .b_data_valid_pong(b_data_valid_pong_delay8_13), .mode(1'b0));
processing_element pe8_14(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay22), .in_a(in_a_8_14_NC),  .in_a_chain(a8_13to8_14), .in_b(b7_14to8_14), .in_c(matrixC7_14), .out_a(out_a_8_14_NC), .out_a_chain(a8_14to8_15), .out_b(b8_14to9_14), .out_b0(b8_14to9_14_ping), .out_b1(b8_14to9_14_pong), .out_c(matrixC8_14), .b_data_valid_ping(b_data_valid_ping_delay8_14), .b_data_valid_pong(b_data_valid_pong_delay8_14), .mode(1'b0));
processing_element pe8_15(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay23), .in_a(in_a_8_15_NC),  .in_a_chain(a8_14to8_15), .in_b(b7_15to8_15), .in_c(matrixC7_15), .out_a(out_a_8_15_NC), .out_a_chain(a8_15to8_16), .out_b(b8_15to9_15), .out_b0(b8_15to9_15_ping), .out_b1(b8_15to9_15_pong), .out_c(matrixC8_15), .b_data_valid_ping(b_data_valid_ping_delay8_15), .b_data_valid_pong(b_data_valid_pong_delay8_15), .mode(1'b0));
processing_element pe9_0(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay9), .in_a(a9),   .in_a_chain(in_a_chain_9_0_NC),   .in_b(b8_0to9_0), .in_c(matrixC8_0), .out_a(out_a_9_0_NC), .out_a_chain(a9_0to9_1), .out_b(b9_0to10_0), .out_b0(b9_0to10_0_ping), .out_b1(b9_0to10_0_pong), .out_c(matrixC9_0), .b_data_valid_ping(b_data_valid_ping_delay9_0), .b_data_valid_pong(b_data_valid_pong_delay9_0), .mode(1'b1));
processing_element pe9_1(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay10), .in_a(in_a_9_1_NC),  .in_a_chain(a9_0to9_1), .in_b(b8_1to9_1), .in_c(matrixC8_1), .out_a(out_a_9_1_NC), .out_a_chain(a9_1to9_2), .out_b(b9_1to10_1), .out_b0(b9_1to10_1_ping), .out_b1(b9_1to10_1_pong), .out_c(matrixC9_1), .b_data_valid_ping(b_data_valid_ping_delay9_1), .b_data_valid_pong(b_data_valid_pong_delay9_1), .mode(1'b0));
processing_element pe9_2(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay11), .in_a(in_a_9_2_NC),  .in_a_chain(a9_1to9_2), .in_b(b8_2to9_2), .in_c(matrixC8_2), .out_a(out_a_9_2_NC), .out_a_chain(a9_2to9_3), .out_b(b9_2to10_2), .out_b0(b9_2to10_2_ping), .out_b1(b9_2to10_2_pong), .out_c(matrixC9_2), .b_data_valid_ping(b_data_valid_ping_delay9_2), .b_data_valid_pong(b_data_valid_pong_delay9_2), .mode(1'b0));
processing_element pe9_3(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay12), .in_a(in_a_9_3_NC),  .in_a_chain(a9_2to9_3), .in_b(b8_3to9_3), .in_c(matrixC8_3), .out_a(out_a_9_3_NC), .out_a_chain(a9_3to9_4), .out_b(b9_3to10_3), .out_b0(b9_3to10_3_ping), .out_b1(b9_3to10_3_pong), .out_c(matrixC9_3), .b_data_valid_ping(b_data_valid_ping_delay9_3), .b_data_valid_pong(b_data_valid_pong_delay9_3), .mode(1'b0));
processing_element pe9_4(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay13), .in_a(in_a_9_4_NC),  .in_a_chain(a9_3to9_4), .in_b(b8_4to9_4), .in_c(matrixC8_4), .out_a(out_a_9_4_NC), .out_a_chain(a9_4to9_5), .out_b(b9_4to10_4), .out_b0(b9_4to10_4_ping), .out_b1(b9_4to10_4_pong), .out_c(matrixC9_4), .b_data_valid_ping(b_data_valid_ping_delay9_4), .b_data_valid_pong(b_data_valid_pong_delay9_4), .mode(1'b0));
processing_element pe9_5(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay14), .in_a(in_a_9_5_NC),  .in_a_chain(a9_4to9_5), .in_b(b8_5to9_5), .in_c(matrixC8_5), .out_a(out_a_9_5_NC), .out_a_chain(a9_5to9_6), .out_b(b9_5to10_5), .out_b0(b9_5to10_5_ping), .out_b1(b9_5to10_5_pong), .out_c(matrixC9_5), .b_data_valid_ping(b_data_valid_ping_delay9_5), .b_data_valid_pong(b_data_valid_pong_delay9_5), .mode(1'b0));
processing_element pe9_6(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay15), .in_a(in_a_9_6_NC),  .in_a_chain(a9_5to9_6), .in_b(b8_6to9_6), .in_c(matrixC8_6), .out_a(out_a_9_6_NC), .out_a_chain(a9_6to9_7), .out_b(b9_6to10_6), .out_b0(b9_6to10_6_ping), .out_b1(b9_6to10_6_pong), .out_c(matrixC9_6), .b_data_valid_ping(b_data_valid_ping_delay9_6), .b_data_valid_pong(b_data_valid_pong_delay9_6), .mode(1'b0));
processing_element pe9_7(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay16), .in_a(in_a_9_7_NC),  .in_a_chain(a9_6to9_7), .in_b(b8_7to9_7), .in_c(matrixC8_7), .out_a(out_a_9_7_NC), .out_a_chain(a9_7to9_8), .out_b(b9_7to10_7), .out_b0(b9_7to10_7_ping), .out_b1(b9_7to10_7_pong), .out_c(matrixC9_7), .b_data_valid_ping(b_data_valid_ping_delay9_7), .b_data_valid_pong(b_data_valid_pong_delay9_7), .mode(1'b0));
processing_element pe9_8(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay17), .in_a(in_a_9_8_NC),  .in_a_chain(a9_7to9_8), .in_b(b8_8to9_8), .in_c(matrixC8_8), .out_a(out_a_9_8_NC), .out_a_chain(a9_8to9_9), .out_b(b9_8to10_8), .out_b0(b9_8to10_8_ping), .out_b1(b9_8to10_8_pong), .out_c(matrixC9_8), .b_data_valid_ping(b_data_valid_ping_delay9_8), .b_data_valid_pong(b_data_valid_pong_delay9_8), .mode(1'b0));
processing_element pe9_9(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay18), .in_a(in_a_9_9_NC),  .in_a_chain(a9_8to9_9), .in_b(b8_9to9_9), .in_c(matrixC8_9), .out_a(out_a_9_9_NC), .out_a_chain(a9_9to9_10), .out_b(b9_9to10_9), .out_b0(b9_9to10_9_ping), .out_b1(b9_9to10_9_pong), .out_c(matrixC9_9), .b_data_valid_ping(b_data_valid_ping_delay9_9), .b_data_valid_pong(b_data_valid_pong_delay9_9), .mode(1'b0));
processing_element pe9_10(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay19), .in_a(in_a_9_10_NC),  .in_a_chain(a9_9to9_10), .in_b(b8_10to9_10), .in_c(matrixC8_10), .out_a(out_a_9_10_NC), .out_a_chain(a9_10to9_11), .out_b(b9_10to10_10), .out_b0(b9_10to10_10_ping), .out_b1(b9_10to10_10_pong), .out_c(matrixC9_10), .b_data_valid_ping(b_data_valid_ping_delay9_10), .b_data_valid_pong(b_data_valid_pong_delay9_10), .mode(1'b0));
processing_element pe9_11(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay20), .in_a(in_a_9_11_NC),  .in_a_chain(a9_10to9_11), .in_b(b8_11to9_11), .in_c(matrixC8_11), .out_a(out_a_9_11_NC), .out_a_chain(a9_11to9_12), .out_b(b9_11to10_11), .out_b0(b9_11to10_11_ping), .out_b1(b9_11to10_11_pong), .out_c(matrixC9_11), .b_data_valid_ping(b_data_valid_ping_delay9_11), .b_data_valid_pong(b_data_valid_pong_delay9_11), .mode(1'b0));
processing_element pe9_12(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay21), .in_a(in_a_9_12_NC),  .in_a_chain(a9_11to9_12), .in_b(b8_12to9_12), .in_c(matrixC8_12), .out_a(out_a_9_12_NC), .out_a_chain(a9_12to9_13), .out_b(b9_12to10_12), .out_b0(b9_12to10_12_ping), .out_b1(b9_12to10_12_pong), .out_c(matrixC9_12), .b_data_valid_ping(b_data_valid_ping_delay9_12), .b_data_valid_pong(b_data_valid_pong_delay9_12), .mode(1'b0));
processing_element pe9_13(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay22), .in_a(in_a_9_13_NC),  .in_a_chain(a9_12to9_13), .in_b(b8_13to9_13), .in_c(matrixC8_13), .out_a(out_a_9_13_NC), .out_a_chain(a9_13to9_14), .out_b(b9_13to10_13), .out_b0(b9_13to10_13_ping), .out_b1(b9_13to10_13_pong), .out_c(matrixC9_13), .b_data_valid_ping(b_data_valid_ping_delay9_13), .b_data_valid_pong(b_data_valid_pong_delay9_13), .mode(1'b0));
processing_element pe9_14(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay23), .in_a(in_a_9_14_NC),  .in_a_chain(a9_13to9_14), .in_b(b8_14to9_14), .in_c(matrixC8_14), .out_a(out_a_9_14_NC), .out_a_chain(a9_14to9_15), .out_b(b9_14to10_14), .out_b0(b9_14to10_14_ping), .out_b1(b9_14to10_14_pong), .out_c(matrixC9_14), .b_data_valid_ping(b_data_valid_ping_delay9_14), .b_data_valid_pong(b_data_valid_pong_delay9_14), .mode(1'b0));
processing_element pe9_15(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay24), .in_a(in_a_9_15_NC),  .in_a_chain(a9_14to9_15), .in_b(b8_15to9_15), .in_c(matrixC8_15), .out_a(out_a_9_15_NC), .out_a_chain(a9_15to9_16), .out_b(b9_15to10_15), .out_b0(b9_15to10_15_ping), .out_b1(b9_15to10_15_pong), .out_c(matrixC9_15), .b_data_valid_ping(b_data_valid_ping_delay9_15), .b_data_valid_pong(b_data_valid_pong_delay9_15), .mode(1'b0));
processing_element pe10_0(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay10), .in_a(a10),   .in_a_chain(in_a_chain_10_0_NC),   .in_b(b9_0to10_0), .in_c(matrixC9_0), .out_a(out_a_10_0_NC), .out_a_chain(a10_0to10_1), .out_b(b10_0to11_0), .out_b0(b10_0to11_0_ping), .out_b1(b10_0to11_0_pong), .out_c(matrixC10_0), .b_data_valid_ping(b_data_valid_ping_delay10_0), .b_data_valid_pong(b_data_valid_pong_delay10_0), .mode(1'b1));
processing_element pe10_1(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay11), .in_a(in_a_10_1_NC),  .in_a_chain(a10_0to10_1), .in_b(b9_1to10_1), .in_c(matrixC9_1), .out_a(out_a_10_1_NC), .out_a_chain(a10_1to10_2), .out_b(b10_1to11_1), .out_b0(b10_1to11_1_ping), .out_b1(b10_1to11_1_pong), .out_c(matrixC10_1), .b_data_valid_ping(b_data_valid_ping_delay10_1), .b_data_valid_pong(b_data_valid_pong_delay10_1), .mode(1'b0));
processing_element pe10_2(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay12), .in_a(in_a_10_2_NC),  .in_a_chain(a10_1to10_2), .in_b(b9_2to10_2), .in_c(matrixC9_2), .out_a(out_a_10_2_NC), .out_a_chain(a10_2to10_3), .out_b(b10_2to11_2), .out_b0(b10_2to11_2_ping), .out_b1(b10_2to11_2_pong), .out_c(matrixC10_2), .b_data_valid_ping(b_data_valid_ping_delay10_2), .b_data_valid_pong(b_data_valid_pong_delay10_2), .mode(1'b0));
processing_element pe10_3(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay13), .in_a(in_a_10_3_NC),  .in_a_chain(a10_2to10_3), .in_b(b9_3to10_3), .in_c(matrixC9_3), .out_a(out_a_10_3_NC), .out_a_chain(a10_3to10_4), .out_b(b10_3to11_3), .out_b0(b10_3to11_3_ping), .out_b1(b10_3to11_3_pong), .out_c(matrixC10_3), .b_data_valid_ping(b_data_valid_ping_delay10_3), .b_data_valid_pong(b_data_valid_pong_delay10_3), .mode(1'b0));
processing_element pe10_4(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay14), .in_a(in_a_10_4_NC),  .in_a_chain(a10_3to10_4), .in_b(b9_4to10_4), .in_c(matrixC9_4), .out_a(out_a_10_4_NC), .out_a_chain(a10_4to10_5), .out_b(b10_4to11_4), .out_b0(b10_4to11_4_ping), .out_b1(b10_4to11_4_pong), .out_c(matrixC10_4), .b_data_valid_ping(b_data_valid_ping_delay10_4), .b_data_valid_pong(b_data_valid_pong_delay10_4), .mode(1'b0));
processing_element pe10_5(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay15), .in_a(in_a_10_5_NC),  .in_a_chain(a10_4to10_5), .in_b(b9_5to10_5), .in_c(matrixC9_5), .out_a(out_a_10_5_NC), .out_a_chain(a10_5to10_6), .out_b(b10_5to11_5), .out_b0(b10_5to11_5_ping), .out_b1(b10_5to11_5_pong), .out_c(matrixC10_5), .b_data_valid_ping(b_data_valid_ping_delay10_5), .b_data_valid_pong(b_data_valid_pong_delay10_5), .mode(1'b0));
processing_element pe10_6(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay16), .in_a(in_a_10_6_NC),  .in_a_chain(a10_5to10_6), .in_b(b9_6to10_6), .in_c(matrixC9_6), .out_a(out_a_10_6_NC), .out_a_chain(a10_6to10_7), .out_b(b10_6to11_6), .out_b0(b10_6to11_6_ping), .out_b1(b10_6to11_6_pong), .out_c(matrixC10_6), .b_data_valid_ping(b_data_valid_ping_delay10_6), .b_data_valid_pong(b_data_valid_pong_delay10_6), .mode(1'b0));
processing_element pe10_7(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay17), .in_a(in_a_10_7_NC),  .in_a_chain(a10_6to10_7), .in_b(b9_7to10_7), .in_c(matrixC9_7), .out_a(out_a_10_7_NC), .out_a_chain(a10_7to10_8), .out_b(b10_7to11_7), .out_b0(b10_7to11_7_ping), .out_b1(b10_7to11_7_pong), .out_c(matrixC10_7), .b_data_valid_ping(b_data_valid_ping_delay10_7), .b_data_valid_pong(b_data_valid_pong_delay10_7), .mode(1'b0));
processing_element pe10_8(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay18), .in_a(in_a_10_8_NC),  .in_a_chain(a10_7to10_8), .in_b(b9_8to10_8), .in_c(matrixC9_8), .out_a(out_a_10_8_NC), .out_a_chain(a10_8to10_9), .out_b(b10_8to11_8), .out_b0(b10_8to11_8_ping), .out_b1(b10_8to11_8_pong), .out_c(matrixC10_8), .b_data_valid_ping(b_data_valid_ping_delay10_8), .b_data_valid_pong(b_data_valid_pong_delay10_8), .mode(1'b0));
processing_element pe10_9(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay19), .in_a(in_a_10_9_NC),  .in_a_chain(a10_8to10_9), .in_b(b9_9to10_9), .in_c(matrixC9_9), .out_a(out_a_10_9_NC), .out_a_chain(a10_9to10_10), .out_b(b10_9to11_9), .out_b0(b10_9to11_9_ping), .out_b1(b10_9to11_9_pong), .out_c(matrixC10_9), .b_data_valid_ping(b_data_valid_ping_delay10_9), .b_data_valid_pong(b_data_valid_pong_delay10_9), .mode(1'b0));
processing_element pe10_10(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay20), .in_a(in_a_10_10_NC),  .in_a_chain(a10_9to10_10), .in_b(b9_10to10_10), .in_c(matrixC9_10), .out_a(out_a_10_10_NC), .out_a_chain(a10_10to10_11), .out_b(b10_10to11_10), .out_b0(b10_10to11_10_ping), .out_b1(b10_10to11_10_pong), .out_c(matrixC10_10), .b_data_valid_ping(b_data_valid_ping_delay10_10), .b_data_valid_pong(b_data_valid_pong_delay10_10), .mode(1'b0));
processing_element pe10_11(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay21), .in_a(in_a_10_11_NC),  .in_a_chain(a10_10to10_11), .in_b(b9_11to10_11), .in_c(matrixC9_11), .out_a(out_a_10_11_NC), .out_a_chain(a10_11to10_12), .out_b(b10_11to11_11), .out_b0(b10_11to11_11_ping), .out_b1(b10_11to11_11_pong), .out_c(matrixC10_11), .b_data_valid_ping(b_data_valid_ping_delay10_11), .b_data_valid_pong(b_data_valid_pong_delay10_11), .mode(1'b0));
processing_element pe10_12(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay22), .in_a(in_a_10_12_NC),  .in_a_chain(a10_11to10_12), .in_b(b9_12to10_12), .in_c(matrixC9_12), .out_a(out_a_10_12_NC), .out_a_chain(a10_12to10_13), .out_b(b10_12to11_12), .out_b0(b10_12to11_12_ping), .out_b1(b10_12to11_12_pong), .out_c(matrixC10_12), .b_data_valid_ping(b_data_valid_ping_delay10_12), .b_data_valid_pong(b_data_valid_pong_delay10_12), .mode(1'b0));
processing_element pe10_13(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay23), .in_a(in_a_10_13_NC),  .in_a_chain(a10_12to10_13), .in_b(b9_13to10_13), .in_c(matrixC9_13), .out_a(out_a_10_13_NC), .out_a_chain(a10_13to10_14), .out_b(b10_13to11_13), .out_b0(b10_13to11_13_ping), .out_b1(b10_13to11_13_pong), .out_c(matrixC10_13), .b_data_valid_ping(b_data_valid_ping_delay10_13), .b_data_valid_pong(b_data_valid_pong_delay10_13), .mode(1'b0));
processing_element pe10_14(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay24), .in_a(in_a_10_14_NC),  .in_a_chain(a10_13to10_14), .in_b(b9_14to10_14), .in_c(matrixC9_14), .out_a(out_a_10_14_NC), .out_a_chain(a10_14to10_15), .out_b(b10_14to11_14), .out_b0(b10_14to11_14_ping), .out_b1(b10_14to11_14_pong), .out_c(matrixC10_14), .b_data_valid_ping(b_data_valid_ping_delay10_14), .b_data_valid_pong(b_data_valid_pong_delay10_14), .mode(1'b0));
processing_element pe10_15(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay25), .in_a(in_a_10_15_NC),  .in_a_chain(a10_14to10_15), .in_b(b9_15to10_15), .in_c(matrixC9_15), .out_a(out_a_10_15_NC), .out_a_chain(a10_15to10_16), .out_b(b10_15to11_15), .out_b0(b10_15to11_15_ping), .out_b1(b10_15to11_15_pong), .out_c(matrixC10_15), .b_data_valid_ping(b_data_valid_ping_delay10_15), .b_data_valid_pong(b_data_valid_pong_delay10_15), .mode(1'b0));
processing_element pe11_0(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay11), .in_a(a11),   .in_a_chain(in_a_chain_11_0_NC),   .in_b(b10_0to11_0), .in_c(matrixC10_0), .out_a(out_a_11_0_NC), .out_a_chain(a11_0to11_1), .out_b(b11_0to12_0), .out_b0(b11_0to12_0_ping), .out_b1(b11_0to12_0_pong), .out_c(matrixC11_0), .b_data_valid_ping(b_data_valid_ping_delay11_0), .b_data_valid_pong(b_data_valid_pong_delay11_0), .mode(1'b1));
processing_element pe11_1(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay12), .in_a(in_a_11_1_NC),  .in_a_chain(a11_0to11_1), .in_b(b10_1to11_1), .in_c(matrixC10_1), .out_a(out_a_11_1_NC), .out_a_chain(a11_1to11_2), .out_b(b11_1to12_1), .out_b0(b11_1to12_1_ping), .out_b1(b11_1to12_1_pong), .out_c(matrixC11_1), .b_data_valid_ping(b_data_valid_ping_delay11_1), .b_data_valid_pong(b_data_valid_pong_delay11_1), .mode(1'b0));
processing_element pe11_2(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay13), .in_a(in_a_11_2_NC),  .in_a_chain(a11_1to11_2), .in_b(b10_2to11_2), .in_c(matrixC10_2), .out_a(out_a_11_2_NC), .out_a_chain(a11_2to11_3), .out_b(b11_2to12_2), .out_b0(b11_2to12_2_ping), .out_b1(b11_2to12_2_pong), .out_c(matrixC11_2), .b_data_valid_ping(b_data_valid_ping_delay11_2), .b_data_valid_pong(b_data_valid_pong_delay11_2), .mode(1'b0));
processing_element pe11_3(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay14), .in_a(in_a_11_3_NC),  .in_a_chain(a11_2to11_3), .in_b(b10_3to11_3), .in_c(matrixC10_3), .out_a(out_a_11_3_NC), .out_a_chain(a11_3to11_4), .out_b(b11_3to12_3), .out_b0(b11_3to12_3_ping), .out_b1(b11_3to12_3_pong), .out_c(matrixC11_3), .b_data_valid_ping(b_data_valid_ping_delay11_3), .b_data_valid_pong(b_data_valid_pong_delay11_3), .mode(1'b0));
processing_element pe11_4(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay15), .in_a(in_a_11_4_NC),  .in_a_chain(a11_3to11_4), .in_b(b10_4to11_4), .in_c(matrixC10_4), .out_a(out_a_11_4_NC), .out_a_chain(a11_4to11_5), .out_b(b11_4to12_4), .out_b0(b11_4to12_4_ping), .out_b1(b11_4to12_4_pong), .out_c(matrixC11_4), .b_data_valid_ping(b_data_valid_ping_delay11_4), .b_data_valid_pong(b_data_valid_pong_delay11_4), .mode(1'b0));
processing_element pe11_5(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay16), .in_a(in_a_11_5_NC),  .in_a_chain(a11_4to11_5), .in_b(b10_5to11_5), .in_c(matrixC10_5), .out_a(out_a_11_5_NC), .out_a_chain(a11_5to11_6), .out_b(b11_5to12_5), .out_b0(b11_5to12_5_ping), .out_b1(b11_5to12_5_pong), .out_c(matrixC11_5), .b_data_valid_ping(b_data_valid_ping_delay11_5), .b_data_valid_pong(b_data_valid_pong_delay11_5), .mode(1'b0));
processing_element pe11_6(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay17), .in_a(in_a_11_6_NC),  .in_a_chain(a11_5to11_6), .in_b(b10_6to11_6), .in_c(matrixC10_6), .out_a(out_a_11_6_NC), .out_a_chain(a11_6to11_7), .out_b(b11_6to12_6), .out_b0(b11_6to12_6_ping), .out_b1(b11_6to12_6_pong), .out_c(matrixC11_6), .b_data_valid_ping(b_data_valid_ping_delay11_6), .b_data_valid_pong(b_data_valid_pong_delay11_6), .mode(1'b0));
processing_element pe11_7(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay18), .in_a(in_a_11_7_NC),  .in_a_chain(a11_6to11_7), .in_b(b10_7to11_7), .in_c(matrixC10_7), .out_a(out_a_11_7_NC), .out_a_chain(a11_7to11_8), .out_b(b11_7to12_7), .out_b0(b11_7to12_7_ping), .out_b1(b11_7to12_7_pong), .out_c(matrixC11_7), .b_data_valid_ping(b_data_valid_ping_delay11_7), .b_data_valid_pong(b_data_valid_pong_delay11_7), .mode(1'b0));
processing_element pe11_8(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay19), .in_a(in_a_11_8_NC),  .in_a_chain(a11_7to11_8), .in_b(b10_8to11_8), .in_c(matrixC10_8), .out_a(out_a_11_8_NC), .out_a_chain(a11_8to11_9), .out_b(b11_8to12_8), .out_b0(b11_8to12_8_ping), .out_b1(b11_8to12_8_pong), .out_c(matrixC11_8), .b_data_valid_ping(b_data_valid_ping_delay11_8), .b_data_valid_pong(b_data_valid_pong_delay11_8), .mode(1'b0));
processing_element pe11_9(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay20), .in_a(in_a_11_9_NC),  .in_a_chain(a11_8to11_9), .in_b(b10_9to11_9), .in_c(matrixC10_9), .out_a(out_a_11_9_NC), .out_a_chain(a11_9to11_10), .out_b(b11_9to12_9), .out_b0(b11_9to12_9_ping), .out_b1(b11_9to12_9_pong), .out_c(matrixC11_9), .b_data_valid_ping(b_data_valid_ping_delay11_9), .b_data_valid_pong(b_data_valid_pong_delay11_9), .mode(1'b0));
processing_element pe11_10(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay21), .in_a(in_a_11_10_NC),  .in_a_chain(a11_9to11_10), .in_b(b10_10to11_10), .in_c(matrixC10_10), .out_a(out_a_11_10_NC), .out_a_chain(a11_10to11_11), .out_b(b11_10to12_10), .out_b0(b11_10to12_10_ping), .out_b1(b11_10to12_10_pong), .out_c(matrixC11_10), .b_data_valid_ping(b_data_valid_ping_delay11_10), .b_data_valid_pong(b_data_valid_pong_delay11_10), .mode(1'b0));
processing_element pe11_11(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay22), .in_a(in_a_11_11_NC),  .in_a_chain(a11_10to11_11), .in_b(b10_11to11_11), .in_c(matrixC10_11), .out_a(out_a_11_11_NC), .out_a_chain(a11_11to11_12), .out_b(b11_11to12_11), .out_b0(b11_11to12_11_ping), .out_b1(b11_11to12_11_pong), .out_c(matrixC11_11), .b_data_valid_ping(b_data_valid_ping_delay11_11), .b_data_valid_pong(b_data_valid_pong_delay11_11), .mode(1'b0));
processing_element pe11_12(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay23), .in_a(in_a_11_12_NC),  .in_a_chain(a11_11to11_12), .in_b(b10_12to11_12), .in_c(matrixC10_12), .out_a(out_a_11_12_NC), .out_a_chain(a11_12to11_13), .out_b(b11_12to12_12), .out_b0(b11_12to12_12_ping), .out_b1(b11_12to12_12_pong), .out_c(matrixC11_12), .b_data_valid_ping(b_data_valid_ping_delay11_12), .b_data_valid_pong(b_data_valid_pong_delay11_12), .mode(1'b0));
processing_element pe11_13(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay24), .in_a(in_a_11_13_NC),  .in_a_chain(a11_12to11_13), .in_b(b10_13to11_13), .in_c(matrixC10_13), .out_a(out_a_11_13_NC), .out_a_chain(a11_13to11_14), .out_b(b11_13to12_13), .out_b0(b11_13to12_13_ping), .out_b1(b11_13to12_13_pong), .out_c(matrixC11_13), .b_data_valid_ping(b_data_valid_ping_delay11_13), .b_data_valid_pong(b_data_valid_pong_delay11_13), .mode(1'b0));
processing_element pe11_14(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay25), .in_a(in_a_11_14_NC),  .in_a_chain(a11_13to11_14), .in_b(b10_14to11_14), .in_c(matrixC10_14), .out_a(out_a_11_14_NC), .out_a_chain(a11_14to11_15), .out_b(b11_14to12_14), .out_b0(b11_14to12_14_ping), .out_b1(b11_14to12_14_pong), .out_c(matrixC11_14), .b_data_valid_ping(b_data_valid_ping_delay11_14), .b_data_valid_pong(b_data_valid_pong_delay11_14), .mode(1'b0));
processing_element pe11_15(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay26), .in_a(in_a_11_15_NC),  .in_a_chain(a11_14to11_15), .in_b(b10_15to11_15), .in_c(matrixC10_15), .out_a(out_a_11_15_NC), .out_a_chain(a11_15to11_16), .out_b(b11_15to12_15), .out_b0(b11_15to12_15_ping), .out_b1(b11_15to12_15_pong), .out_c(matrixC11_15), .b_data_valid_ping(b_data_valid_ping_delay11_15), .b_data_valid_pong(b_data_valid_pong_delay11_15), .mode(1'b0));
processing_element pe12_0(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay12), .in_a(a12),   .in_a_chain(in_a_chain_12_0_NC),   .in_b(b11_0to12_0), .in_c(matrixC11_0), .out_a(out_a_12_0_NC), .out_a_chain(a12_0to12_1), .out_b(b12_0to13_0), .out_b0(b12_0to13_0_ping), .out_b1(b12_0to13_0_pong), .out_c(matrixC12_0), .b_data_valid_ping(b_data_valid_ping_delay12_0), .b_data_valid_pong(b_data_valid_pong_delay12_0), .mode(1'b1));
processing_element pe12_1(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay13), .in_a(in_a_12_1_NC),  .in_a_chain(a12_0to12_1), .in_b(b11_1to12_1), .in_c(matrixC11_1), .out_a(out_a_12_1_NC), .out_a_chain(a12_1to12_2), .out_b(b12_1to13_1), .out_b0(b12_1to13_1_ping), .out_b1(b12_1to13_1_pong), .out_c(matrixC12_1), .b_data_valid_ping(b_data_valid_ping_delay12_1), .b_data_valid_pong(b_data_valid_pong_delay12_1), .mode(1'b0));
processing_element pe12_2(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay14), .in_a(in_a_12_2_NC),  .in_a_chain(a12_1to12_2), .in_b(b11_2to12_2), .in_c(matrixC11_2), .out_a(out_a_12_2_NC), .out_a_chain(a12_2to12_3), .out_b(b12_2to13_2), .out_b0(b12_2to13_2_ping), .out_b1(b12_2to13_2_pong), .out_c(matrixC12_2), .b_data_valid_ping(b_data_valid_ping_delay12_2), .b_data_valid_pong(b_data_valid_pong_delay12_2), .mode(1'b0));
processing_element pe12_3(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay15), .in_a(in_a_12_3_NC),  .in_a_chain(a12_2to12_3), .in_b(b11_3to12_3), .in_c(matrixC11_3), .out_a(out_a_12_3_NC), .out_a_chain(a12_3to12_4), .out_b(b12_3to13_3), .out_b0(b12_3to13_3_ping), .out_b1(b12_3to13_3_pong), .out_c(matrixC12_3), .b_data_valid_ping(b_data_valid_ping_delay12_3), .b_data_valid_pong(b_data_valid_pong_delay12_3), .mode(1'b0));
processing_element pe12_4(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay16), .in_a(in_a_12_4_NC),  .in_a_chain(a12_3to12_4), .in_b(b11_4to12_4), .in_c(matrixC11_4), .out_a(out_a_12_4_NC), .out_a_chain(a12_4to12_5), .out_b(b12_4to13_4), .out_b0(b12_4to13_4_ping), .out_b1(b12_4to13_4_pong), .out_c(matrixC12_4), .b_data_valid_ping(b_data_valid_ping_delay12_4), .b_data_valid_pong(b_data_valid_pong_delay12_4), .mode(1'b0));
processing_element pe12_5(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay17), .in_a(in_a_12_5_NC),  .in_a_chain(a12_4to12_5), .in_b(b11_5to12_5), .in_c(matrixC11_5), .out_a(out_a_12_5_NC), .out_a_chain(a12_5to12_6), .out_b(b12_5to13_5), .out_b0(b12_5to13_5_ping), .out_b1(b12_5to13_5_pong), .out_c(matrixC12_5), .b_data_valid_ping(b_data_valid_ping_delay12_5), .b_data_valid_pong(b_data_valid_pong_delay12_5), .mode(1'b0));
processing_element pe12_6(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay18), .in_a(in_a_12_6_NC),  .in_a_chain(a12_5to12_6), .in_b(b11_6to12_6), .in_c(matrixC11_6), .out_a(out_a_12_6_NC), .out_a_chain(a12_6to12_7), .out_b(b12_6to13_6), .out_b0(b12_6to13_6_ping), .out_b1(b12_6to13_6_pong), .out_c(matrixC12_6), .b_data_valid_ping(b_data_valid_ping_delay12_6), .b_data_valid_pong(b_data_valid_pong_delay12_6), .mode(1'b0));
processing_element pe12_7(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay19), .in_a(in_a_12_7_NC),  .in_a_chain(a12_6to12_7), .in_b(b11_7to12_7), .in_c(matrixC11_7), .out_a(out_a_12_7_NC), .out_a_chain(a12_7to12_8), .out_b(b12_7to13_7), .out_b0(b12_7to13_7_ping), .out_b1(b12_7to13_7_pong), .out_c(matrixC12_7), .b_data_valid_ping(b_data_valid_ping_delay12_7), .b_data_valid_pong(b_data_valid_pong_delay12_7), .mode(1'b0));
processing_element pe12_8(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay20), .in_a(in_a_12_8_NC),  .in_a_chain(a12_7to12_8), .in_b(b11_8to12_8), .in_c(matrixC11_8), .out_a(out_a_12_8_NC), .out_a_chain(a12_8to12_9), .out_b(b12_8to13_8), .out_b0(b12_8to13_8_ping), .out_b1(b12_8to13_8_pong), .out_c(matrixC12_8), .b_data_valid_ping(b_data_valid_ping_delay12_8), .b_data_valid_pong(b_data_valid_pong_delay12_8), .mode(1'b0));
processing_element pe12_9(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay21), .in_a(in_a_12_9_NC),  .in_a_chain(a12_8to12_9), .in_b(b11_9to12_9), .in_c(matrixC11_9), .out_a(out_a_12_9_NC), .out_a_chain(a12_9to12_10), .out_b(b12_9to13_9), .out_b0(b12_9to13_9_ping), .out_b1(b12_9to13_9_pong), .out_c(matrixC12_9), .b_data_valid_ping(b_data_valid_ping_delay12_9), .b_data_valid_pong(b_data_valid_pong_delay12_9), .mode(1'b0));
processing_element pe12_10(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay22), .in_a(in_a_12_10_NC),  .in_a_chain(a12_9to12_10), .in_b(b11_10to12_10), .in_c(matrixC11_10), .out_a(out_a_12_10_NC), .out_a_chain(a12_10to12_11), .out_b(b12_10to13_10), .out_b0(b12_10to13_10_ping), .out_b1(b12_10to13_10_pong), .out_c(matrixC12_10), .b_data_valid_ping(b_data_valid_ping_delay12_10), .b_data_valid_pong(b_data_valid_pong_delay12_10), .mode(1'b0));
processing_element pe12_11(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay23), .in_a(in_a_12_11_NC),  .in_a_chain(a12_10to12_11), .in_b(b11_11to12_11), .in_c(matrixC11_11), .out_a(out_a_12_11_NC), .out_a_chain(a12_11to12_12), .out_b(b12_11to13_11), .out_b0(b12_11to13_11_ping), .out_b1(b12_11to13_11_pong), .out_c(matrixC12_11), .b_data_valid_ping(b_data_valid_ping_delay12_11), .b_data_valid_pong(b_data_valid_pong_delay12_11), .mode(1'b0));
processing_element pe12_12(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay24), .in_a(in_a_12_12_NC),  .in_a_chain(a12_11to12_12), .in_b(b11_12to12_12), .in_c(matrixC11_12), .out_a(out_a_12_12_NC), .out_a_chain(a12_12to12_13), .out_b(b12_12to13_12), .out_b0(b12_12to13_12_ping), .out_b1(b12_12to13_12_pong), .out_c(matrixC12_12), .b_data_valid_ping(b_data_valid_ping_delay12_12), .b_data_valid_pong(b_data_valid_pong_delay12_12), .mode(1'b0));
processing_element pe12_13(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay25), .in_a(in_a_12_13_NC),  .in_a_chain(a12_12to12_13), .in_b(b11_13to12_13), .in_c(matrixC11_13), .out_a(out_a_12_13_NC), .out_a_chain(a12_13to12_14), .out_b(b12_13to13_13), .out_b0(b12_13to13_13_ping), .out_b1(b12_13to13_13_pong), .out_c(matrixC12_13), .b_data_valid_ping(b_data_valid_ping_delay12_13), .b_data_valid_pong(b_data_valid_pong_delay12_13), .mode(1'b0));
processing_element pe12_14(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay26), .in_a(in_a_12_14_NC),  .in_a_chain(a12_13to12_14), .in_b(b11_14to12_14), .in_c(matrixC11_14), .out_a(out_a_12_14_NC), .out_a_chain(a12_14to12_15), .out_b(b12_14to13_14), .out_b0(b12_14to13_14_ping), .out_b1(b12_14to13_14_pong), .out_c(matrixC12_14), .b_data_valid_ping(b_data_valid_ping_delay12_14), .b_data_valid_pong(b_data_valid_pong_delay12_14), .mode(1'b0));
processing_element pe12_15(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay27), .in_a(in_a_12_15_NC),  .in_a_chain(a12_14to12_15), .in_b(b11_15to12_15), .in_c(matrixC11_15), .out_a(out_a_12_15_NC), .out_a_chain(a12_15to12_16), .out_b(b12_15to13_15), .out_b0(b12_15to13_15_ping), .out_b1(b12_15to13_15_pong), .out_c(matrixC12_15), .b_data_valid_ping(b_data_valid_ping_delay12_15), .b_data_valid_pong(b_data_valid_pong_delay12_15), .mode(1'b0));
processing_element pe13_0(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay13), .in_a(a13),   .in_a_chain(in_a_chain_13_0_NC),   .in_b(b12_0to13_0), .in_c(matrixC12_0), .out_a(out_a_13_0_NC), .out_a_chain(a13_0to13_1), .out_b(b13_0to14_0), .out_b0(b13_0to14_0_ping), .out_b1(b13_0to14_0_pong), .out_c(matrixC13_0), .b_data_valid_ping(b_data_valid_ping_delay13_0), .b_data_valid_pong(b_data_valid_pong_delay13_0), .mode(1'b1));
processing_element pe13_1(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay14), .in_a(in_a_13_1_NC),  .in_a_chain(a13_0to13_1), .in_b(b12_1to13_1), .in_c(matrixC12_1), .out_a(out_a_13_1_NC), .out_a_chain(a13_1to13_2), .out_b(b13_1to14_1), .out_b0(b13_1to14_1_ping), .out_b1(b13_1to14_1_pong), .out_c(matrixC13_1), .b_data_valid_ping(b_data_valid_ping_delay13_1), .b_data_valid_pong(b_data_valid_pong_delay13_1), .mode(1'b0));
processing_element pe13_2(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay15), .in_a(in_a_13_2_NC),  .in_a_chain(a13_1to13_2), .in_b(b12_2to13_2), .in_c(matrixC12_2), .out_a(out_a_13_2_NC), .out_a_chain(a13_2to13_3), .out_b(b13_2to14_2), .out_b0(b13_2to14_2_ping), .out_b1(b13_2to14_2_pong), .out_c(matrixC13_2), .b_data_valid_ping(b_data_valid_ping_delay13_2), .b_data_valid_pong(b_data_valid_pong_delay13_2), .mode(1'b0));
processing_element pe13_3(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay16), .in_a(in_a_13_3_NC),  .in_a_chain(a13_2to13_3), .in_b(b12_3to13_3), .in_c(matrixC12_3), .out_a(out_a_13_3_NC), .out_a_chain(a13_3to13_4), .out_b(b13_3to14_3), .out_b0(b13_3to14_3_ping), .out_b1(b13_3to14_3_pong), .out_c(matrixC13_3), .b_data_valid_ping(b_data_valid_ping_delay13_3), .b_data_valid_pong(b_data_valid_pong_delay13_3), .mode(1'b0));
processing_element pe13_4(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay17), .in_a(in_a_13_4_NC),  .in_a_chain(a13_3to13_4), .in_b(b12_4to13_4), .in_c(matrixC12_4), .out_a(out_a_13_4_NC), .out_a_chain(a13_4to13_5), .out_b(b13_4to14_4), .out_b0(b13_4to14_4_ping), .out_b1(b13_4to14_4_pong), .out_c(matrixC13_4), .b_data_valid_ping(b_data_valid_ping_delay13_4), .b_data_valid_pong(b_data_valid_pong_delay13_4), .mode(1'b0));
processing_element pe13_5(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay18), .in_a(in_a_13_5_NC),  .in_a_chain(a13_4to13_5), .in_b(b12_5to13_5), .in_c(matrixC12_5), .out_a(out_a_13_5_NC), .out_a_chain(a13_5to13_6), .out_b(b13_5to14_5), .out_b0(b13_5to14_5_ping), .out_b1(b13_5to14_5_pong), .out_c(matrixC13_5), .b_data_valid_ping(b_data_valid_ping_delay13_5), .b_data_valid_pong(b_data_valid_pong_delay13_5), .mode(1'b0));
processing_element pe13_6(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay19), .in_a(in_a_13_6_NC),  .in_a_chain(a13_5to13_6), .in_b(b12_6to13_6), .in_c(matrixC12_6), .out_a(out_a_13_6_NC), .out_a_chain(a13_6to13_7), .out_b(b13_6to14_6), .out_b0(b13_6to14_6_ping), .out_b1(b13_6to14_6_pong), .out_c(matrixC13_6), .b_data_valid_ping(b_data_valid_ping_delay13_6), .b_data_valid_pong(b_data_valid_pong_delay13_6), .mode(1'b0));
processing_element pe13_7(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay20), .in_a(in_a_13_7_NC),  .in_a_chain(a13_6to13_7), .in_b(b12_7to13_7), .in_c(matrixC12_7), .out_a(out_a_13_7_NC), .out_a_chain(a13_7to13_8), .out_b(b13_7to14_7), .out_b0(b13_7to14_7_ping), .out_b1(b13_7to14_7_pong), .out_c(matrixC13_7), .b_data_valid_ping(b_data_valid_ping_delay13_7), .b_data_valid_pong(b_data_valid_pong_delay13_7), .mode(1'b0));
processing_element pe13_8(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay21), .in_a(in_a_13_8_NC),  .in_a_chain(a13_7to13_8), .in_b(b12_8to13_8), .in_c(matrixC12_8), .out_a(out_a_13_8_NC), .out_a_chain(a13_8to13_9), .out_b(b13_8to14_8), .out_b0(b13_8to14_8_ping), .out_b1(b13_8to14_8_pong), .out_c(matrixC13_8), .b_data_valid_ping(b_data_valid_ping_delay13_8), .b_data_valid_pong(b_data_valid_pong_delay13_8), .mode(1'b0));
processing_element pe13_9(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay22), .in_a(in_a_13_9_NC),  .in_a_chain(a13_8to13_9), .in_b(b12_9to13_9), .in_c(matrixC12_9), .out_a(out_a_13_9_NC), .out_a_chain(a13_9to13_10), .out_b(b13_9to14_9), .out_b0(b13_9to14_9_ping), .out_b1(b13_9to14_9_pong), .out_c(matrixC13_9), .b_data_valid_ping(b_data_valid_ping_delay13_9), .b_data_valid_pong(b_data_valid_pong_delay13_9), .mode(1'b0));
processing_element pe13_10(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay23), .in_a(in_a_13_10_NC),  .in_a_chain(a13_9to13_10), .in_b(b12_10to13_10), .in_c(matrixC12_10), .out_a(out_a_13_10_NC), .out_a_chain(a13_10to13_11), .out_b(b13_10to14_10), .out_b0(b13_10to14_10_ping), .out_b1(b13_10to14_10_pong), .out_c(matrixC13_10), .b_data_valid_ping(b_data_valid_ping_delay13_10), .b_data_valid_pong(b_data_valid_pong_delay13_10), .mode(1'b0));
processing_element pe13_11(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay24), .in_a(in_a_13_11_NC),  .in_a_chain(a13_10to13_11), .in_b(b12_11to13_11), .in_c(matrixC12_11), .out_a(out_a_13_11_NC), .out_a_chain(a13_11to13_12), .out_b(b13_11to14_11), .out_b0(b13_11to14_11_ping), .out_b1(b13_11to14_11_pong), .out_c(matrixC13_11), .b_data_valid_ping(b_data_valid_ping_delay13_11), .b_data_valid_pong(b_data_valid_pong_delay13_11), .mode(1'b0));
processing_element pe13_12(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay25), .in_a(in_a_13_12_NC),  .in_a_chain(a13_11to13_12), .in_b(b12_12to13_12), .in_c(matrixC12_12), .out_a(out_a_13_12_NC), .out_a_chain(a13_12to13_13), .out_b(b13_12to14_12), .out_b0(b13_12to14_12_ping), .out_b1(b13_12to14_12_pong), .out_c(matrixC13_12), .b_data_valid_ping(b_data_valid_ping_delay13_12), .b_data_valid_pong(b_data_valid_pong_delay13_12), .mode(1'b0));
processing_element pe13_13(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay26), .in_a(in_a_13_13_NC),  .in_a_chain(a13_12to13_13), .in_b(b12_13to13_13), .in_c(matrixC12_13), .out_a(out_a_13_13_NC), .out_a_chain(a13_13to13_14), .out_b(b13_13to14_13), .out_b0(b13_13to14_13_ping), .out_b1(b13_13to14_13_pong), .out_c(matrixC13_13), .b_data_valid_ping(b_data_valid_ping_delay13_13), .b_data_valid_pong(b_data_valid_pong_delay13_13), .mode(1'b0));
processing_element pe13_14(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay27), .in_a(in_a_13_14_NC),  .in_a_chain(a13_13to13_14), .in_b(b12_14to13_14), .in_c(matrixC12_14), .out_a(out_a_13_14_NC), .out_a_chain(a13_14to13_15), .out_b(b13_14to14_14), .out_b0(b13_14to14_14_ping), .out_b1(b13_14to14_14_pong), .out_c(matrixC13_14), .b_data_valid_ping(b_data_valid_ping_delay13_14), .b_data_valid_pong(b_data_valid_pong_delay13_14), .mode(1'b0));
processing_element pe13_15(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay28), .in_a(in_a_13_15_NC),  .in_a_chain(a13_14to13_15), .in_b(b12_15to13_15), .in_c(matrixC12_15), .out_a(out_a_13_15_NC), .out_a_chain(a13_15to13_16), .out_b(b13_15to14_15), .out_b0(b13_15to14_15_ping), .out_b1(b13_15to14_15_pong), .out_c(matrixC13_15), .b_data_valid_ping(b_data_valid_ping_delay13_15), .b_data_valid_pong(b_data_valid_pong_delay13_15), .mode(1'b0));
processing_element pe14_0(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay14), .in_a(a14),   .in_a_chain(in_a_chain_14_0_NC),   .in_b(b13_0to14_0), .in_c(matrixC13_0), .out_a(out_a_14_0_NC), .out_a_chain(a14_0to14_1), .out_b(b14_0to15_0), .out_b0(b14_0to15_0_ping), .out_b1(b14_0to15_0_pong), .out_c(matrixC14_0), .b_data_valid_ping(b_data_valid_ping_delay14_0), .b_data_valid_pong(b_data_valid_pong_delay14_0), .mode(1'b1));
processing_element pe14_1(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay15), .in_a(in_a_14_1_NC),  .in_a_chain(a14_0to14_1), .in_b(b13_1to14_1), .in_c(matrixC13_1), .out_a(out_a_14_1_NC), .out_a_chain(a14_1to14_2), .out_b(b14_1to15_1), .out_b0(b14_1to15_1_ping), .out_b1(b14_1to15_1_pong), .out_c(matrixC14_1), .b_data_valid_ping(b_data_valid_ping_delay14_1), .b_data_valid_pong(b_data_valid_pong_delay14_1), .mode(1'b0));
processing_element pe14_2(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay16), .in_a(in_a_14_2_NC),  .in_a_chain(a14_1to14_2), .in_b(b13_2to14_2), .in_c(matrixC13_2), .out_a(out_a_14_2_NC), .out_a_chain(a14_2to14_3), .out_b(b14_2to15_2), .out_b0(b14_2to15_2_ping), .out_b1(b14_2to15_2_pong), .out_c(matrixC14_2), .b_data_valid_ping(b_data_valid_ping_delay14_2), .b_data_valid_pong(b_data_valid_pong_delay14_2), .mode(1'b0));
processing_element pe14_3(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay17), .in_a(in_a_14_3_NC),  .in_a_chain(a14_2to14_3), .in_b(b13_3to14_3), .in_c(matrixC13_3), .out_a(out_a_14_3_NC), .out_a_chain(a14_3to14_4), .out_b(b14_3to15_3), .out_b0(b14_3to15_3_ping), .out_b1(b14_3to15_3_pong), .out_c(matrixC14_3), .b_data_valid_ping(b_data_valid_ping_delay14_3), .b_data_valid_pong(b_data_valid_pong_delay14_3), .mode(1'b0));
processing_element pe14_4(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay18), .in_a(in_a_14_4_NC),  .in_a_chain(a14_3to14_4), .in_b(b13_4to14_4), .in_c(matrixC13_4), .out_a(out_a_14_4_NC), .out_a_chain(a14_4to14_5), .out_b(b14_4to15_4), .out_b0(b14_4to15_4_ping), .out_b1(b14_4to15_4_pong), .out_c(matrixC14_4), .b_data_valid_ping(b_data_valid_ping_delay14_4), .b_data_valid_pong(b_data_valid_pong_delay14_4), .mode(1'b0));
processing_element pe14_5(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay19), .in_a(in_a_14_5_NC),  .in_a_chain(a14_4to14_5), .in_b(b13_5to14_5), .in_c(matrixC13_5), .out_a(out_a_14_5_NC), .out_a_chain(a14_5to14_6), .out_b(b14_5to15_5), .out_b0(b14_5to15_5_ping), .out_b1(b14_5to15_5_pong), .out_c(matrixC14_5), .b_data_valid_ping(b_data_valid_ping_delay14_5), .b_data_valid_pong(b_data_valid_pong_delay14_5), .mode(1'b0));
processing_element pe14_6(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay20), .in_a(in_a_14_6_NC),  .in_a_chain(a14_5to14_6), .in_b(b13_6to14_6), .in_c(matrixC13_6), .out_a(out_a_14_6_NC), .out_a_chain(a14_6to14_7), .out_b(b14_6to15_6), .out_b0(b14_6to15_6_ping), .out_b1(b14_6to15_6_pong), .out_c(matrixC14_6), .b_data_valid_ping(b_data_valid_ping_delay14_6), .b_data_valid_pong(b_data_valid_pong_delay14_6), .mode(1'b0));
processing_element pe14_7(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay21), .in_a(in_a_14_7_NC),  .in_a_chain(a14_6to14_7), .in_b(b13_7to14_7), .in_c(matrixC13_7), .out_a(out_a_14_7_NC), .out_a_chain(a14_7to14_8), .out_b(b14_7to15_7), .out_b0(b14_7to15_7_ping), .out_b1(b14_7to15_7_pong), .out_c(matrixC14_7), .b_data_valid_ping(b_data_valid_ping_delay14_7), .b_data_valid_pong(b_data_valid_pong_delay14_7), .mode(1'b0));
processing_element pe14_8(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay22), .in_a(in_a_14_8_NC),  .in_a_chain(a14_7to14_8), .in_b(b13_8to14_8), .in_c(matrixC13_8), .out_a(out_a_14_8_NC), .out_a_chain(a14_8to14_9), .out_b(b14_8to15_8), .out_b0(b14_8to15_8_ping), .out_b1(b14_8to15_8_pong), .out_c(matrixC14_8), .b_data_valid_ping(b_data_valid_ping_delay14_8), .b_data_valid_pong(b_data_valid_pong_delay14_8), .mode(1'b0));
processing_element pe14_9(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay23), .in_a(in_a_14_9_NC),  .in_a_chain(a14_8to14_9), .in_b(b13_9to14_9), .in_c(matrixC13_9), .out_a(out_a_14_9_NC), .out_a_chain(a14_9to14_10), .out_b(b14_9to15_9), .out_b0(b14_9to15_9_ping), .out_b1(b14_9to15_9_pong), .out_c(matrixC14_9), .b_data_valid_ping(b_data_valid_ping_delay14_9), .b_data_valid_pong(b_data_valid_pong_delay14_9), .mode(1'b0));
processing_element pe14_10(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay24), .in_a(in_a_14_10_NC),  .in_a_chain(a14_9to14_10), .in_b(b13_10to14_10), .in_c(matrixC13_10), .out_a(out_a_14_10_NC), .out_a_chain(a14_10to14_11), .out_b(b14_10to15_10), .out_b0(b14_10to15_10_ping), .out_b1(b14_10to15_10_pong), .out_c(matrixC14_10), .b_data_valid_ping(b_data_valid_ping_delay14_10), .b_data_valid_pong(b_data_valid_pong_delay14_10), .mode(1'b0));
processing_element pe14_11(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay25), .in_a(in_a_14_11_NC),  .in_a_chain(a14_10to14_11), .in_b(b13_11to14_11), .in_c(matrixC13_11), .out_a(out_a_14_11_NC), .out_a_chain(a14_11to14_12), .out_b(b14_11to15_11), .out_b0(b14_11to15_11_ping), .out_b1(b14_11to15_11_pong), .out_c(matrixC14_11), .b_data_valid_ping(b_data_valid_ping_delay14_11), .b_data_valid_pong(b_data_valid_pong_delay14_11), .mode(1'b0));
processing_element pe14_12(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay26), .in_a(in_a_14_12_NC),  .in_a_chain(a14_11to14_12), .in_b(b13_12to14_12), .in_c(matrixC13_12), .out_a(out_a_14_12_NC), .out_a_chain(a14_12to14_13), .out_b(b14_12to15_12), .out_b0(b14_12to15_12_ping), .out_b1(b14_12to15_12_pong), .out_c(matrixC14_12), .b_data_valid_ping(b_data_valid_ping_delay14_12), .b_data_valid_pong(b_data_valid_pong_delay14_12), .mode(1'b0));
processing_element pe14_13(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay27), .in_a(in_a_14_13_NC),  .in_a_chain(a14_12to14_13), .in_b(b13_13to14_13), .in_c(matrixC13_13), .out_a(out_a_14_13_NC), .out_a_chain(a14_13to14_14), .out_b(b14_13to15_13), .out_b0(b14_13to15_13_ping), .out_b1(b14_13to15_13_pong), .out_c(matrixC14_13), .b_data_valid_ping(b_data_valid_ping_delay14_13), .b_data_valid_pong(b_data_valid_pong_delay14_13), .mode(1'b0));
processing_element pe14_14(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay28), .in_a(in_a_14_14_NC),  .in_a_chain(a14_13to14_14), .in_b(b13_14to14_14), .in_c(matrixC13_14), .out_a(out_a_14_14_NC), .out_a_chain(a14_14to14_15), .out_b(b14_14to15_14), .out_b0(b14_14to15_14_ping), .out_b1(b14_14to15_14_pong), .out_c(matrixC14_14), .b_data_valid_ping(b_data_valid_ping_delay14_14), .b_data_valid_pong(b_data_valid_pong_delay14_14), .mode(1'b0));
processing_element pe14_15(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay29), .in_a(in_a_14_15_NC),  .in_a_chain(a14_14to14_15), .in_b(b13_15to14_15), .in_c(matrixC13_15), .out_a(out_a_14_15_NC), .out_a_chain(a14_15to14_16), .out_b(b14_15to15_15), .out_b0(b14_15to15_15_ping), .out_b1(b14_15to15_15_pong), .out_c(matrixC14_15), .b_data_valid_ping(b_data_valid_ping_delay14_15), .b_data_valid_pong(b_data_valid_pong_delay14_15), .mode(1'b0));
processing_element pe15_0(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay15), .in_a(a15),   .in_a_chain(in_a_chain_15_0_NC),   .in_b(b14_0to15_0), .in_c(matrixC14_0), .out_a(out_a_15_0_NC), .out_a_chain(a15_0to15_1), .out_b(b15_0to16_0), .out_b0(b15_0to16_0_ping), .out_b1(b15_0to16_0_pong), .out_c(matrixC15_0), .b_data_valid_ping(b_data_valid_ping_delay15_0), .b_data_valid_pong(b_data_valid_pong_delay15_0), .mode(1'b1));
processing_element pe15_1(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay16), .in_a(in_a_15_1_NC),  .in_a_chain(a15_0to15_1), .in_b(b14_1to15_1), .in_c(matrixC14_1), .out_a(out_a_15_1_NC), .out_a_chain(a15_1to15_2), .out_b(b15_1to16_1), .out_b0(b15_1to16_1_ping), .out_b1(b15_1to16_1_pong), .out_c(matrixC15_1), .b_data_valid_ping(b_data_valid_ping_delay15_1), .b_data_valid_pong(b_data_valid_pong_delay15_1), .mode(1'b0));
processing_element pe15_2(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay17), .in_a(in_a_15_2_NC),  .in_a_chain(a15_1to15_2), .in_b(b14_2to15_2), .in_c(matrixC14_2), .out_a(out_a_15_2_NC), .out_a_chain(a15_2to15_3), .out_b(b15_2to16_2), .out_b0(b15_2to16_2_ping), .out_b1(b15_2to16_2_pong), .out_c(matrixC15_2), .b_data_valid_ping(b_data_valid_ping_delay15_2), .b_data_valid_pong(b_data_valid_pong_delay15_2), .mode(1'b0));
processing_element pe15_3(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay18), .in_a(in_a_15_3_NC),  .in_a_chain(a15_2to15_3), .in_b(b14_3to15_3), .in_c(matrixC14_3), .out_a(out_a_15_3_NC), .out_a_chain(a15_3to15_4), .out_b(b15_3to16_3), .out_b0(b15_3to16_3_ping), .out_b1(b15_3to16_3_pong), .out_c(matrixC15_3), .b_data_valid_ping(b_data_valid_ping_delay15_3), .b_data_valid_pong(b_data_valid_pong_delay15_3), .mode(1'b0));
processing_element pe15_4(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay19), .in_a(in_a_15_4_NC),  .in_a_chain(a15_3to15_4), .in_b(b14_4to15_4), .in_c(matrixC14_4), .out_a(out_a_15_4_NC), .out_a_chain(a15_4to15_5), .out_b(b15_4to16_4), .out_b0(b15_4to16_4_ping), .out_b1(b15_4to16_4_pong), .out_c(matrixC15_4), .b_data_valid_ping(b_data_valid_ping_delay15_4), .b_data_valid_pong(b_data_valid_pong_delay15_4), .mode(1'b0));
processing_element pe15_5(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay20), .in_a(in_a_15_5_NC),  .in_a_chain(a15_4to15_5), .in_b(b14_5to15_5), .in_c(matrixC14_5), .out_a(out_a_15_5_NC), .out_a_chain(a15_5to15_6), .out_b(b15_5to16_5), .out_b0(b15_5to16_5_ping), .out_b1(b15_5to16_5_pong), .out_c(matrixC15_5), .b_data_valid_ping(b_data_valid_ping_delay15_5), .b_data_valid_pong(b_data_valid_pong_delay15_5), .mode(1'b0));
processing_element pe15_6(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay21), .in_a(in_a_15_6_NC),  .in_a_chain(a15_5to15_6), .in_b(b14_6to15_6), .in_c(matrixC14_6), .out_a(out_a_15_6_NC), .out_a_chain(a15_6to15_7), .out_b(b15_6to16_6), .out_b0(b15_6to16_6_ping), .out_b1(b15_6to16_6_pong), .out_c(matrixC15_6), .b_data_valid_ping(b_data_valid_ping_delay15_6), .b_data_valid_pong(b_data_valid_pong_delay15_6), .mode(1'b0));
processing_element pe15_7(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay22), .in_a(in_a_15_7_NC),  .in_a_chain(a15_6to15_7), .in_b(b14_7to15_7), .in_c(matrixC14_7), .out_a(out_a_15_7_NC), .out_a_chain(a15_7to15_8), .out_b(b15_7to16_7), .out_b0(b15_7to16_7_ping), .out_b1(b15_7to16_7_pong), .out_c(matrixC15_7), .b_data_valid_ping(b_data_valid_ping_delay15_7), .b_data_valid_pong(b_data_valid_pong_delay15_7), .mode(1'b0));
processing_element pe15_8(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay23), .in_a(in_a_15_8_NC),  .in_a_chain(a15_7to15_8), .in_b(b14_8to15_8), .in_c(matrixC14_8), .out_a(out_a_15_8_NC), .out_a_chain(a15_8to15_9), .out_b(b15_8to16_8), .out_b0(b15_8to16_8_ping), .out_b1(b15_8to16_8_pong), .out_c(matrixC15_8), .b_data_valid_ping(b_data_valid_ping_delay15_8), .b_data_valid_pong(b_data_valid_pong_delay15_8), .mode(1'b0));
processing_element pe15_9(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay24), .in_a(in_a_15_9_NC),  .in_a_chain(a15_8to15_9), .in_b(b14_9to15_9), .in_c(matrixC14_9), .out_a(out_a_15_9_NC), .out_a_chain(a15_9to15_10), .out_b(b15_9to16_9), .out_b0(b15_9to16_9_ping), .out_b1(b15_9to16_9_pong), .out_c(matrixC15_9), .b_data_valid_ping(b_data_valid_ping_delay15_9), .b_data_valid_pong(b_data_valid_pong_delay15_9), .mode(1'b0));
processing_element pe15_10(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay25), .in_a(in_a_15_10_NC),  .in_a_chain(a15_9to15_10), .in_b(b14_10to15_10), .in_c(matrixC14_10), .out_a(out_a_15_10_NC), .out_a_chain(a15_10to15_11), .out_b(b15_10to16_10), .out_b0(b15_10to16_10_ping), .out_b1(b15_10to16_10_pong), .out_c(matrixC15_10), .b_data_valid_ping(b_data_valid_ping_delay15_10), .b_data_valid_pong(b_data_valid_pong_delay15_10), .mode(1'b0));
processing_element pe15_11(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay26), .in_a(in_a_15_11_NC),  .in_a_chain(a15_10to15_11), .in_b(b14_11to15_11), .in_c(matrixC14_11), .out_a(out_a_15_11_NC), .out_a_chain(a15_11to15_12), .out_b(b15_11to16_11), .out_b0(b15_11to16_11_ping), .out_b1(b15_11to16_11_pong), .out_c(matrixC15_11), .b_data_valid_ping(b_data_valid_ping_delay15_11), .b_data_valid_pong(b_data_valid_pong_delay15_11), .mode(1'b0));
processing_element pe15_12(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay27), .in_a(in_a_15_12_NC),  .in_a_chain(a15_11to15_12), .in_b(b14_12to15_12), .in_c(matrixC14_12), .out_a(out_a_15_12_NC), .out_a_chain(a15_12to15_13), .out_b(b15_12to16_12), .out_b0(b15_12to16_12_ping), .out_b1(b15_12to16_12_pong), .out_c(matrixC15_12), .b_data_valid_ping(b_data_valid_ping_delay15_12), .b_data_valid_pong(b_data_valid_pong_delay15_12), .mode(1'b0));
processing_element pe15_13(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay28), .in_a(in_a_15_13_NC),  .in_a_chain(a15_12to15_13), .in_b(b14_13to15_13), .in_c(matrixC14_13), .out_a(out_a_15_13_NC), .out_a_chain(a15_13to15_14), .out_b(b15_13to16_13), .out_b0(b15_13to16_13_ping), .out_b1(b15_13to16_13_pong), .out_c(matrixC15_13), .b_data_valid_ping(b_data_valid_ping_delay15_13), .b_data_valid_pong(b_data_valid_pong_delay15_13), .mode(1'b0));
processing_element pe15_14(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay29), .in_a(in_a_15_14_NC),  .in_a_chain(a15_13to15_14), .in_b(b14_14to15_14), .in_c(matrixC14_14), .out_a(out_a_15_14_NC), .out_a_chain(a15_14to15_15), .out_b(b15_14to16_14), .out_b0(b15_14to16_14_ping), .out_b1(b15_14to16_14_pong), .out_c(matrixC15_14), .b_data_valid_ping(b_data_valid_ping_delay15_14), .b_data_valid_pong(b_data_valid_pong_delay15_14), .mode(1'b0));
processing_element pe15_15(.reset(effective_rst), .clk(clk), .b_data_sel(b_data_sel_delay30), .in_a(in_a_15_15_NC),  .in_a_chain(a15_14to15_15), .in_b(b14_15to15_15), .in_c(matrixC14_15), .out_a(out_a_15_15_NC), .out_a_chain(a15_15to15_16), .out_b(b15_15to16_15), .out_b0(b15_15to16_15_ping), .out_b1(b15_15to16_15_pong), .out_c(matrixC15_15), .b_data_valid_ping(b_data_valid_ping_delay15_15), .b_data_valid_pong(b_data_valid_pong_delay15_15), .mode(1'b0));
  
//assign a_data_out = {a15_15to15_16, a14_15to14_16, a13_15to13_16, a12_15to12_16, a11_15to11_16, a10_15to10_16, a9_15to9_16, a8_15to8_16, a7_15to7_16, a6_15to6_16, a5_15to5_16, a4_15to4_16, a3_15to3_16, a2_15to2_16, a1_15to1_16, a0_15to0_16};
//assign b_data_out = {b15_15to16_15, b15_14to16_14, b15_13to16_13, b15_12to16_12, b15_11to16_11, b15_10to16_10, b15_9to16_9, b15_8to16_8, b15_7to16_7, b15_6to16_6, b15_5to16_5, b15_4to16_4, b15_3to16_3, b15_2to16_2, b15_1to16_1, b15_0to16_0};

endmodule

//////////////////////////////////////////////////////////////////////////
// Processing element (PE)
//////////////////////////////////////////////////////////////////////////

module processing_element(
    reset, 
    clk, 
    b_data_sel,
    in_a,
    in_a_chain,
    in_b,
    in_c,
    out_a,
    out_a_chain,
    out_b, 
    out_b0,
    out_b1,
    out_c,
    b_data_valid_ping,
    b_data_valid_pong,
    mode
 );

input reset;
input clk;
input b_data_sel;
input b_data_valid_ping;
input b_data_valid_pong;
input  [`DWIDTH-1:0] in_a;
input  [`DWIDTH-1:0] in_a_chain;
input  [`DWIDTH-1:0] in_b; 
input  [`DWIDTH-1:0] in_c; 
output [`DWIDTH-1:0] out_a;
output [`DWIDTH-1:0] out_a_chain;
output [`DWIDTH-1:0] out_b;
output [`DWIDTH-1:0] out_b0;
output [`DWIDTH-1:0] out_b1;
output [`DWIDTH-1:0] out_c;  
input mode;

`ifdef complex_dsp

 wire [18:0] scanout;
 wire [63:0] chainout; //unconnected
 wire [63:0] result;
 wire [17:0] ax;
 wire [18:0] ay;
 wire [35:0] bx;
 wire [63:0] chainin; 
 wire [18:0] scanin;
 wire [11:0] mode_sigs;

 assign mode_sigs = 12'b010101010101;  //Any value of mode_sigs (structural, not functional, correctness)
 assign ax = {{(18-`DWIDTH){1'b0}}, in_a};
 assign ay = {{(19-`DWIDTH){1'b0}}, in_b};
 assign bx = 36'b0;
 assign scanin = {{(18-`DWIDTH){1'b0}}, in_a_chain};
 assign chainin = in_c;

  //We will instantiate DSP slices with input chaining and output chaining.
  //Input chaining is only supported in the 18x19 mode or the 27x27 mode.
  //We will use the input chain provided by the DSP for the A input. For B, the chain will be manual.

  mult_add_int u_pe(
    .clk(clk),
    .reset(reset),
    .mode_sigs(mode_sigs),
    .ax(ax),
    .ay(ay),
    .bx(bx),
    .chainin(chainin),
    .scanin(scanin),
    .result(result),
    .chainout(chainout),
    .scanout(scanout)
  );

reg [`DWIDTH-1:0] out_b0;
reg [`DWIDTH-1:0] out_b1;

wire [`DWIDTH-1:0] in_mac;
wire [`DWIDTH-1:0] out_c;

assign out_c = result;
assign in_mac = (b_data_sel==0)? out_b0 : out_b1;
        
assign out_a = result; 
assign out_a_chain = scanout;

always @(posedge clk)begin 
    if (reset) begin
        out_b0<=0;
    end
    if(b_data_valid_ping == 1) begin
        out_b0<=in_b;
    end
end

always @(posedge clk)begin 
    if (reset) begin
        out_b1<=0;
    end
    if(b_data_valid_pong == 1) begin
        out_b1<=in_b;
    end
end

`else

reg [`DWIDTH-1:0] out_a;
reg [`DWIDTH-1:0] out_b;
reg [`DWIDTH-1:0] out_b0;
reg [`DWIDTH-1:0] out_b1;

wire [`DWIDTH-1:0] in_mac;
wire [`DWIDTH-1:0] out_c;
wire [`DWIDTH-1:0] out_mac;

assign out_c = out_mac;
assign in_mac = (b_data_sel==0)? out_b0 : out_b1;
        
seq_mac u_mac(.a(out_a), .b(in_mac), .c(in_c), .out(out_mac), .reset(reset), .clk(clk));

always @(posedge clk)begin
    if(reset) begin
        out_a<=0;
    end
    else begin  
        out_a<=mode ? in_a : in_a_chain;
    end
end

assign out_a_chain = out_a;

always @(posedge clk)begin
    if(reset) begin
        out_b<=0;
    end
    else begin  
        out_b<=in_b;
    end
end

always @(posedge clk)begin 
    if (reset) begin
        out_b0<=0;
    end
    if(b_data_valid_ping == 1) begin
        out_b0<=in_b;
    end
end

always @(posedge clk)begin 
    if (reset) begin
        out_b1<=0;
    end
    if(b_data_valid_pong == 1) begin
        out_b1<=in_b;
    end
end

`endif

endmodule

`ifndef complex_dsp

//////////////////////////////////////////////////////////////////////////
// Multiply-and-accumulate (MAC) block
//////////////////////////////////////////////////////////////////////////

module seq_mac(a, b, c, out, reset, clk);

input [`DWIDTH-1:0] a;
input [`DWIDTH-1:0] b;
input [`DWIDTH-1:0] c;
input reset;
input clk;
output [`DWIDTH-1:0] out;

wire [`DWIDTH-1:0] mul_out;
wire [`DWIDTH-1:0] add_out;

reg [`DWIDTH-1:0] a_flopped;
reg [`DWIDTH-1:0] b_flopped;
reg [`DWIDTH-1:0] c_flopped;

wire [2*`DWIDTH-1:0] mul_out_temp;
wire [2*`DWIDTH-1:0] mul_out_temp_reg;

always @(posedge clk) begin
  if (reset) begin
    a_flopped <= 0;
    b_flopped <= 0;
    c_flopped <= 0;
  end else begin
    a_flopped <= a;
    b_flopped <= b;
    c_flopped <= c;
  end
end
  
// assign mul_out = a * b;
qmult mult_u1(.i_multiplicand(a_flopped), .i_multiplier(b_flopped), .o_result(mul_out_temp));


// down cast the result
// todo: do a fused multiply add. Truncate only once after the accumulation is complete
assign mul_out = 
    (mul_out_temp[2*`DWIDTH-1] == 0) ?  //positive number
        (
           (|(mul_out_temp[2*`DWIDTH-2 : `DWIDTH-1])) ?  //is any bit from 14:7 is 1, that means overlfow
             {mul_out_temp[2*`DWIDTH-1] , {(`DWIDTH-1){1'b1}}} : //sign bit and then all 1s
             {mul_out_temp[2*`DWIDTH-1] , mul_out_temp[`DWIDTH-2:0]} 
        )
        : //negative number
        (
           (|(mul_out_temp[2*`DWIDTH-2 : `DWIDTH-1])) ?  //is any bit from 14:7 is 0, that means overlfow
             {mul_out_temp[2*`DWIDTH-1] , mul_out_temp[`DWIDTH-2:0]} :
             {mul_out_temp[2*`DWIDTH-1] , {(`DWIDTH-1){1'b0}}} //sign bit and then all 0s
        );


// we just truncate the higher bits of the product
// assign out = mul_out + c_flopped;
qadd add_u1(.a(c_flopped), .b(mul_out), .c(out));

endmodule


//////////////////////////////////////////////////////////////////////////
// Multiplier
//////////////////////////////////////////////////////////////////////////

module qmult(i_multiplicand,i_multiplier,o_result);

input [`DWIDTH-1:0] i_multiplicand;
input [`DWIDTH-1:0] i_multiplier;
output [2*`DWIDTH-1:0] o_result;

assign o_result = i_multiplicand * i_multiplier;
//DW02_mult #(`DWIDTH,`DWIDTH) u_mult(.A(i_multiplicand), .B(i_multiplier), .TC(1'b1), .PRODUCT(o_result));

endmodule


//////////////////////////////////////////////////////////////////////////
// Adder
//////////////////////////////////////////////////////////////////////////
// todo: Output should have one extra bit as compared to the inputs

module qadd(a,b,c);

input [`DWIDTH-1:0] a;
input [`DWIDTH-1:0] b;
output [`DWIDTH-1:0] c;

assign c = a + b;
// DW01_add #(`DWIDTH) u_add(.A(a), .B(b), .CI(1'b0), .SUM(c), .CO());

endmodule

`endif
