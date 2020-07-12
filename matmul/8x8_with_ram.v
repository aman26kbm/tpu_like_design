
`timescale 1ns/1ns
`define DWIDTH 8
`define MASK_WIDTH 8
`define MAT_MUL_SIZE 8
`define LOG2_MAT_MUL_SIZE 3
`define BB_MAT_MUL_SIZE `MAT_MUL_SIZE
`define NUM_CYCLES_IN_MAC 3

//Design with memories
module matrix_multiplication(
  clk, 
  clk_mem, 
  resetn, 
  start_reg,
  clear_done_reg
);

  input clk;
  input clk_mem;
  input resetn;
  input start_reg;
  input clear_done_reg;

		 wire [`AWIDTH-1:0] bram_addr_a;
		 wire [`MAT_MUL_SIZE*`DWIDTH-1:0] bram_rdata_a;
		 wire [`MAT_MUL_SIZE*`DWIDTH-1:0] bram_wdata_a;
		 wire [`MASK_WIDTH-1:0] bram_we_a;
		 wire bram_en_a;

		 wire [`AWIDTH-1:0] bram_addr_b;
		 wire [`MAT_MUL_SIZE*`DWIDTH-1:0] bram_rdata_b;
		 wire [`MAT_MUL_SIZE*`DWIDTH-1:0] bram_wdata_b;
		 wire [`MASK_WIDTH-1:0] bram_we_b;
		 wire bram_en_b;
		
		 wire [`AWIDTH-1:0] bram_addr_c;
		 wire [`MAT_MUL_SIZE*`DWIDTH-1:0] bram_rdata_c;
		 wire [`MAT_MUL_SIZE*`DWIDTH-1:0] bram_wdata_c;
		 wire [`MASK_WIDTH-1:0] bram_we_c;
		 wire bram_en_c;

  reg [3:0] state;

  // BRAM matrix A 
  ram matrix_A (
    .addr0(bram_addr_a),
    .d0(bram_wdata_a), 
    .we0(bram_we_a), 
    .q0(bram_rdata_a), 
    .clk(clk_mem));

  // BRAM matrix B
  ram matrix_B (
    .addr0(bram_addr_b),
    .d0(bram_wdata_b), 
    .we0(bram_we_b), 
    .q0(bram_rdata_b), 
    .clk(clk_mem));

  // BRAM matrix C
  ram matrix_C (
    .addr0(bram_addr_c),
    .d0(bram_wdata_c),
    .we0(bram_we_c),
    .q0(bram_rdata_c),
    .clk(clk_mem));

reg start_mat_mul;
wire done_mat_mul;
	
	always @( posedge clk) begin
      if (resetn == 1'b0) begin
        state <= 4'b0000;
        start_mat_mul <= 1'b0;
      end else begin
        case (state)
        4'b0000: begin
          start_mat_mul <= 1'b0;
          if (start_reg == 1'b1) begin
            state <= 4'b0001;
          end else begin
            state <= 4'b0000;
          end
        end
        
        4'b0001: begin
          start_mat_mul <= 1'b1;	      
          state <= 4'b1010;                    
        end      
        
        
        4'b1010: begin                 
          if (done_mat_mul == 1'b1) begin
            start_mat_mul <= 1'b0;
            state <= 4'b1000;
          end
          else begin
            state <= 4'b1010;
          end
        end

       4'b1000: begin
         if (clear_done_reg == 1'b1) begin
           state <= 4'b0000;
         end
         else begin
           state <= 4'b1000;
         end
       end
      endcase  
	end 
  end

wire c_data_available;

//Connections for bram c (output matrix)
//bram_addr_c -> connected to u_matmul_4x4 block
//bram_rdata_c -> not used
//bram_wdata_c -> connected to u_matmul_4x4 block
//bram_we_c -> set to 1 when c_data is available
//bram_en_c -> hardcoded to 1 

  assign bram_en_c = 1'b1;
  assign bram_we_c = (c_data_available) ? 4'b1111 : 4'b0000;  

//Connections for bram a (first input matrix)
//bram_addr_a -> connected to u_matmul_4x4
//bram_rdata_a -> connected to u_matmul_4x4
//bram_wdata_a -> hardcoded to 0 (this block only reads from bram a)
//bram_we_a -> hardcoded to 0 (this block only reads from bram a)
//bram_en_a -> hardcoded to 1

  assign bram_wdata_a = 32'b0;
  assign bram_en_a = 1'b1;
  assign bram_we_a = 4'b0;
  
//Connections for bram b (second input matrix)
//bram_addr_b -> connected to u_matmul_4x4
//bram_rdata_b -> connected to u_matmul_4x4
//bram_wdata_b -> hardcoded to 0 (this block only reads from bram b)
//bram_we_b -> hardcoded to 0 (this block only reads from bram b)
//bram_en_b -> hardcoded to 1

  assign bram_wdata_b = 32'b0;
  assign bram_en_b = 1'b1;
  assign bram_we_b = 4'b0;
  
//NC wires 
wire [`BB_MAT_MUL_SIZE*`DWIDTH-1:0] a_data_out_NC;
wire [`BB_MAT_MUL_SIZE*`DWIDTH-1:0] b_data_out_NC;
wire [`BB_MAT_MUL_SIZE*`DWIDTH-1:0] a_data_in_NC;
wire [`BB_MAT_MUL_SIZE*`DWIDTH-1:0] b_data_in_NC;

wire reset;
assign reset = ~resetn;

matmul_8x8 u_matmul_8x8(
  .clk(clk),
  .reset(reset),
  .start_mat_mul(start_mat_mul),
  .done_mat_mul(done_mat_mul),
  .a_data(bram_rdata_a),
  .b_data(bram_rdata_b),
  .a_data_in(a_data_in_NC),
  .b_data_in(b_data_in_NC),
  .c_data_in({`BB_MAT_MUL_SIZE*`DWIDTH{1'b0}}),
  .c_data_out(bram_wdata_c),
  .a_data_out(a_data_out_NC),
  .b_data_out(b_data_out_NC),
  .a_addr(bram_addr_a),
  .b_addr(bram_addr_b),
  .c_addr(bram_addr_c),
  .c_data_available(c_data_available),
  .final_mat_mul_size(8'd8),
  .a_loc(8'd0),
  .b_loc(8'd0)
);

endmodule  


module ram (addr0, d0, we0, q0,  clk);

input [`AWIDTH-1:0] addr0;
input [`MASK_WIDTH*`DWIDTH-1:0] d0;
input [`MASK_WIDTH-1:0] we0;
output [`MASK_WIDTH*`DWIDTH-1:0] q0;
input clk;

reg [`MASK_WIDTH*`DWIDTH-1:0] q0;
reg [7:0] ram[((1<<`AWIDTH)-1):0];

always @(posedge clk)  
begin 
        if (we0[0]) ram[addr0+0] <= d0[7:0]; 
        if (we0[1]) ram[addr0+1] <= d0[15:8]; 
        if (we0[2]) ram[addr0+2] <= d0[23:16]; 
        if (we0[3]) ram[addr0+3] <= d0[31:24];
				if (we0[4]) ram[addr0+4] <= d0[39:32];
				if (we0[5]) ram[addr0+5] <= d0[47:40];
				if (we0[6]) ram[addr0+6] <= d0[55:48];
				if (we0[7]) ram[addr0+7] <= d0[63:56]; 
        q0 <= {ram[addr0+7], ram[addr0+6], ram[addr0+5], ram[addr0+4], ram[addr0+3], ram[addr0+2], ram[addr0+1], ram[addr0]};
end

//single_port_ram u_single_port_ram(
//  .data(d0),
//  .we(we0),
//  .addr(addr0),
//  .clk(clk),
//  .out(q0)
//);
endmodule