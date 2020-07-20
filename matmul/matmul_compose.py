import sys
import os.path
from os import path
import pdb
import math
import argparse

data_width = 8
address_width = 11
mem_size = 2048

def ceiling_div(a, b):
  if(a == 0):
    return 0
  
  if(a % b == 0):
    return a//b
  
  return a//b + 1

def write_with_ram(file, basic_block_size, final_block_size):
  #write the top module
  num_of_bram = int(int(final_block_size)/int(basic_block_size))
  file.write('module matrix_multiplication(\n')
  #declare the ports
  file.write('  input clk,\n')
  file.write('  input clk_mem,\n')
  file.write('  input resetn,\n')
  file.write('  input                             PCLK,\n')
  file.write('  input                             PRESETn,\n')
  file.write('  input        [`REG_ADDRWIDTH-1:0] PADDR,\n')
  file.write('  input                             PWRITE,\n')
  file.write('  input                             PSEL,\n')
  file.write('  input                             PENABLE,\n')
  file.write('  input        [`REG_DATAWIDTH-1:0] PWDATA,\n')
  file.write('  output reg   [`REG_DATAWIDTH-1:0] PRDATA,\n')
  file.write('  output reg                        PREADY,\n')
  file.write('  input  [7:0] bram_select,\n')
  file.write('  input  [`AWIDTH-1:0] bram_addr_ext,\n')
  file.write('  output reg [`MAT_MUL_SIZE*`DWIDTH-1:0] bram_rdata_ext,\n')
  file.write('  input  [`MAT_MUL_SIZE*`DWIDTH-1:0] bram_wdata_ext,\n')
  file.write('  input  [`MASK_WIDTH-1:0] bram_we_ext\n')
  file.write(');\n\n')

  file.write("""
  reg start_reg;
  reg clear_done_reg;
  //Dummy register to sync all other invalid/unimplemented addresses
  reg [`REG_DATAWIDTH-1:0] reg_dummy;
  """)

  num_of_bram = int(final_block_size/basic_block_size)
  #print('num of bram is {0}\n'.format(num_of_bram))
  for i in range(num_of_bram):
    file.write("""
  reg [`AWIDTH-1:0] bram_addr_a_{}_0_ext;
  reg [`MAT_MUL_SIZE*`DWIDTH-1:0] bram_rdata_a_{}_0_ext;
  reg [`MAT_MUL_SIZE*`DWIDTH-1:0] bram_wdata_a_{}_0_ext;
  reg [`MASK_WIDTH-1:0] bram_we_a_{}_0_ext;
    """.format(i,i,i,i))
  
  for i in range(num_of_bram):
    file.write("""
  reg [`AWIDTH-1:0] bram_addr_b_0_{}_ext;
  reg [`MAT_MUL_SIZE*`DWIDTH-1:0] bram_rdata_b_0_{}_ext;
  reg [`MAT_MUL_SIZE*`DWIDTH-1:0] bram_wdata_b_0_{}_ext;
  reg [`MASK_WIDTH-1:0] bram_we_b_0_{}_ext;
    """.format(i,i,i,i))

  for i in range(num_of_bram):
    file.write("""
  reg [`AWIDTH-1:0] bram_addr_c_{0}_{1}_ext;
  reg [`MAT_MUL_SIZE*`DWIDTH-1:0] bram_rdata_c_{0}_{1}_ext;
  reg [`MAT_MUL_SIZE*`DWIDTH-1:0] bram_wdata_c_{0}_{1}_ext;
  reg [`MASK_WIDTH-1:0] bram_we_c_{0}_{1}_ext;
    """.format(num_of_bram-1,i))

  for i in range(num_of_bram):
    file.write("""
	wire [`AWIDTH-1:0] bram_addr_a_{0}_0;
	wire [`MAT_MUL_SIZE*`DWIDTH-1:0] bram_rdata_a_{0}_0;
	wire [`MAT_MUL_SIZE*`DWIDTH-1:0] bram_wdata_a_{0}_0;
	wire [`MASK_WIDTH-1:0] bram_we_a_{0}_0;
	wire bram_en_a_{0}_0;
    """.format(i))

  for i in range(num_of_bram):
    file.write("""
	wire [`AWIDTH-1:0] bram_addr_b_0_{0};
	wire [`MAT_MUL_SIZE*`DWIDTH-1:0] bram_rdata_b_0_{0};
	wire [`MAT_MUL_SIZE*`DWIDTH-1:0] bram_wdata_b_0_{0};
	wire [`MASK_WIDTH-1:0] bram_we_b_0_{0};
	wire bram_en_b_0_{0};
    """.format(i))

  for i in range(num_of_bram):
    file.write("""
	wire [`AWIDTH-1:0] bram_addr_c_{0}_{1};
	wire [`MAT_MUL_SIZE*`DWIDTH-1:0] bram_rdata_c_{0}_{1};
	wire [`MAT_MUL_SIZE*`DWIDTH-1:0] bram_wdata_c_{0}_{1};
	wire [`MASK_WIDTH-1:0] bram_we_c_{0}_{1};
	wire bram_en_c_{0}_{1};
    """.format(num_of_bram-1,i))

  file.write("""
  always @* begin
    case (bram_select)
  """)
  
  tot = 0
  for i in range(num_of_bram): 
    file.write("""
      {0}: begin
      bram_addr_a_{1}_0_ext = bram_addr_ext;
      bram_wdata_a_{1}_0_ext = bram_wdata_ext;
      bram_we_a_{1}_0_ext = bram_we_ext;
      bram_rdata_ext = bram_rdata_a_{1}_0_ext;
      end
    """.format(tot,i))
  tot += 1

  for i in range(num_of_bram): 
    file.write("""
      {0}: begin
      bram_addr_b_0_{1}_ext = bram_addr_ext;
      bram_wdata_b_0_{1}_ext = bram_wdata_ext;
      bram_we_b_0_{1}_ext = bram_we_ext;
      bram_rdata_ext = bram_rdata_b_0_{1}_ext;
      end
    """.format(tot,i))
  tot += 1
  
  for i in range(num_of_bram): 
    file.write("""
      {0}: begin
      bram_addr_c_{1}_{2}_ext = bram_addr_ext;
      bram_wdata_c_{1}_{2}_ext = bram_wdata_ext;
      bram_we_c_{1}_{2}_ext = bram_we_ext;
      bram_rdata_ext = bram_rdata_c_{1}_{2}_ext;
      end
    """.format(tot,num_of_bram-1,i))

  file.write("""
      default: begin
      bram_rdata_ext = 0;
      end
    endcase 
  end
  """)

  #matrix A
  file.write(	'\n')
  file.write(	'/////////////////////////////////////////////////\n'
  		'// BRAMs to store matrix A\n'
  		'/////////////////////////////////////////////////\n\n')
  for i in range(num_of_bram):
    file.write("""
  // BRAM matrix A {0}_0
ram matrix_A_{0}_0(
  .addr0(bram_addr_a_{0}_0),
  .d0(bram_wdata_a_{0}_0), 
  .we0(bram_we_a_{0}_0), 
  .q0(bram_rdata_a_{0}_0), 
  .addr1(bram_addr_a_{0}_0_ext),
  .d1(bram_wdata_a_{0}_0_ext), 
  .we1(bram_we_a_{0}_0_ext), 
  .q1(bram_rdata_a_{0}_0_ext), 
  .clk(clk_mem));
  	""".format(i))

  #matrixB
  file.write(	'/////////////////////////////////////////////////\n'
  		'// BRAMs to store matrix B\n'
  		'/////////////////////////////////////////////////\n\n')
  for i in range(num_of_bram):
    file.write("""
  // BRAM matrix B 0_{0}
ram matrix_B_0_{0}(
  .addr0(bram_addr_b_0_{0}),
  .d0(bram_wdata_b_0_{0}), 
  .we0(bram_we_b_0_{0}), 
  .q0(bram_rdata_b_0_{0}), 
  .addr1(bram_addr_b_0_{0}_ext),
  .d1(bram_wdata_b_0_{0}_ext), 
  .we1(bram_we_b_0_{0}_ext), 
  .q1(bram_rdata_b_0_{0}_ext), 
  .clk(clk_mem));
  	""".format(i))
  
  #matrixC
  file.write(	'/////////////////////////////////////////////////\n'
  		'// BRAMs to store matrix C\n'
  		'/////////////////////////////////////////////////\n\n')
  for i in range(num_of_bram):
    file.write("""
  // BRAM matrix C {0}_{1}
ram matrix_C_{0}_{1}(
  .addr0(bram_addr_c_{0}_{1}),
  .d0(bram_wdata_c_{0}_{1}), 
  .we0(bram_we_c_{0}_{1}), 
  .q0(bram_rdata_c_{0}_{1}), 
  .addr1(bram_addr_c_{0}_{1}_ext),
  .d1(bram_wdata_c_{0}_{1}_ext), 
  .we1(bram_we_c_{0}_{1}_ext), 
  .q1(bram_rdata_c_{0}_{1}_ext), 
  .clk(clk_mem));
  	""".format(num_of_bram-1,i))
  

  file.write("""
reg start_mat_mul;
wire done_mat_mul;

reg [3:0] state;
	
////////////////////////////////////////////////////////////////
// Control logic
////////////////////////////////////////////////////////////////
	always @( posedge clk) begin
      if (resetn == 1'b0) begin
        state <= 4'b0000;
        start_mat_mul <= 1'b0;
      end 
      else begin
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

reg [1:0] state_apb;
`define IDLE     2'b00
`define W_ENABLE  2'b01
`define R_ENABLE  2'b10

reg [`AWIDTH-1:0] address_mat_a;
reg [`AWIDTH-1:0] address_mat_b;
reg [`AWIDTH-1:0] address_mat_c;
reg [`MASK_WIDTH-1:0] validity_mask_a_rows;
reg [`MASK_WIDTH-1:0] validity_mask_a_cols_b_rows;
reg [`MASK_WIDTH-1:0] validity_mask_b_cols;
reg [`ADDR_STRIDE_WIDTH-1:0] address_stride_a;
reg [`ADDR_STRIDE_WIDTH-1:0] address_stride_b;
reg [`ADDR_STRIDE_WIDTH-1:0] address_stride_c;

////////////////////////////////////////////////////////////////
// Configuration logic
////////////////////////////////////////////////////////////////
always @(posedge PCLK) begin
  if (PRESETn == 0) begin
    state_apb <= `IDLE;
    PRDATA <= 0;
    PREADY <= 0;
    address_mat_a <= 0;
    address_mat_b <= 0;
    address_mat_c <= 0;
    validity_mask_a_rows <= {`MASK_WIDTH{1'b1}};
    validity_mask_a_cols_b_rows <= {`MASK_WIDTH{1'b1}};
    validity_mask_b_cols <= {`MASK_WIDTH{1'b1}};
    address_stride_a <= `MAT_MUL_SIZE;
    address_stride_b <= `MAT_MUL_SIZE;
    address_stride_c <= `MAT_MUL_SIZE;
  end

  else begin
    case (state_apb)
      `IDLE : begin
        PRDATA <= 0;
        if (PSEL) begin
          if (PWRITE) begin
            state_apb <= `W_ENABLE;
          end
          else begin
            state_apb <= `R_ENABLE;
          end
        end
        PREADY <= 0;
      end

      `W_ENABLE : begin
        if (PSEL && PWRITE && PENABLE) begin
          case (PADDR)
          `REG_START_DONE_ADDR : begin
                                 start_reg <= PWDATA[0];
                                 clear_done_reg <= PWDATA[31];
                                 end
          `REG_MATRIX_A_ADDR   : address_mat_a <= PWDATA[`AWIDTH-1:0];
          `REG_MATRIX_B_ADDR   : address_mat_b <= PWDATA[`AWIDTH-1:0];
          `REG_MATRIX_C_ADDR   : address_mat_c <= PWDATA[`AWIDTH-1:0];
          `REG_VALID_MASK_ADDR : begin
                                 validity_mask_a_rows <= PWDATA[`MASK_WIDTH-1:0];
                                 validity_mask_a_cols_b_rows <= PWDATA[2*`MASK_WIDTH-1:`MASK_WIDTH];
                                 validity_mask_b_cols <= PWDATA[3*`MASK_WIDTH-1:2*`MASK_WIDTH];
                                 end
          `REG_MATRIX_A_STRIDE_ADDR : address_stride_a <= PWDATA[`ADDR_STRIDE_WIDTH-1:0];
          `REG_MATRIX_B_STRIDE_ADDR : address_stride_b <= PWDATA[`ADDR_STRIDE_WIDTH-1:0];
          `REG_MATRIX_C_STRIDE_ADDR : address_stride_c <= PWDATA[`ADDR_STRIDE_WIDTH-1:0];
          default : reg_dummy <= PWDATA; //sink writes to a dummy register
          endcase
          PREADY <=1;          
        end
        state_apb <= `IDLE;
      end

      `R_ENABLE : begin
        if (PSEL && !PWRITE && PENABLE) begin
          PREADY <= 1;
          case (PADDR)
          `REG_START_DONE_ADDR  : PRDATA <= {done_mat_mul, 30'b0, start_mat_mul};
          `REG_MATRIX_A_ADDR    : PRDATA <= address_mat_a;
          `REG_MATRIX_B_ADDR    : PRDATA <= address_mat_b;
          `REG_MATRIX_C_ADDR    : PRDATA <= address_mat_c;
          `REG_VALID_MASK_ADDR  : PRDATA <= {validity_mask_b_cols, validity_mask_a_cols_b_rows, validity_mask_a_rows};
          `REG_MATRIX_A_STRIDE_ADDR : PRDATA <= address_stride_a;
          `REG_MATRIX_B_STRIDE_ADDR : PRDATA <= address_stride_b;
          `REG_MATRIX_C_STRIDE_ADDR : PRDATA <= address_stride_c;
          default : PRDATA <= reg_dummy; //read the dummy register for undefined addresses
          endcase
        end
        state_apb <= `IDLE;
      end
      default: begin
        state_apb <= `IDLE;
      end
    endcase
  end
end  
  
wire reset;
assign reset = ~resetn;
  """)

  for i in range(num_of_bram):
    file.write("""
  wire c_data_{0}_{1}_available;
  assign bram_en_c_{0}_{1} = 1'b1;
  assign bram_we_c_{0}_{1} = (c_data_{0}_{1}_available) ? {{`MASK_WIDTH{{1'b1}}}} : {{`MASK_WIDTH{{1'b0}}}};  
  	""".format(num_of_bram-1,i))

  for i in range(num_of_bram):
    file.write("""
  assign bram_wdata_a_{0}_0 = {{`MAT_MUL_SIZE*`DWIDTH{{1'b0}}}};
  assign bram_en_a_{0}_0 = 1'b1;
  assign bram_we_a_{0}_0 = {{`MASK_WIDTH{{1'b0}}}};
  	""".format(i))

  for i in range(num_of_bram):
    file.write("""
  assign bram_wdata_b_0_{0} = {{`MAT_MUL_SIZE*`DWIDTH{{1'b0}}}};
  assign bram_en_b_0_{0} = 1'b1;
  assign bram_we_b_0_{0} = {{`MASK_WIDTH{{1'b0}}}};\n
  	""".format(i))
  
  #instantiation of systolic matmul
  file.write(	'\n/////////////////////////////////////////////////\n'
  		'// The {0}x{0} matmul instantiation\n'
  		'/////////////////////////////////////////////////\n\n'
  		.format(final_block_size))
  
  file.write("""
  matmul_{0}x{0}_systolic u_matmul_{0}x{0}_systolic (
  .clk(clk),
  .reset(reset),
  .start_mat_mul(start_mat_mul),
  .done_mat_mul(done_mat_mul),
  .address_mat_a(address_mat_a),
  .address_mat_b(address_mat_b),
  .address_mat_c(address_mat_c),
  .address_stride_a(address_stride_a),
  .address_stride_b(address_stride_b),
  .address_stride_c(address_stride_c),
  """.format(final_block_size))

  for i in range(num_of_bram):
    file.write("""
  .a_data_{0}_0(bram_rdata_a_{0}_0),
  .b_data_0_{0}(bram_rdata_b_0_{0}),
  .a_addr_{0}_0(bram_addr_a_{0}_0),
  .b_addr_0_{0}(bram_addr_b_0_{0}),
  	""".format(i))
  
  for i in range(num_of_bram):
    file.write("""
  .c_data_{0}_{1}(bram_wdata_c_{0}_{1}),
  .c_addr_{0}_{1}(bram_addr_c_{0}_{1}),
  .c_data_{0}_{1}_available(c_data_{0}_{1}_available),
   		""".format(num_of_bram-1,i))

  file.write("""
  .validity_mask_a_rows(validity_mask_a_rows),
  .validity_mask_a_cols_b_rows(validity_mask_a_cols_b_rows),
  .validity_mask_b_cols(validity_mask_b_cols)
);
endmodule
  """)

def write_systolic_matmul(file, basic_block_size, final_block_size):
  num_of_bram = int(final_block_size/basic_block_size)
  num_of_IO   = ceiling_div(num_of_bram*num_of_bram, 4)
  #systolic impplementation
  file.write('\n/////////////////////////////////////////////////\n'
  	     '// The {0}x{0} matmul definition\n'
  	     '/////////////////////////////////////////////////\n\n'
  	     .format(final_block_size))
  
  file.write("""
module matmul_{0}x{0}_systolic(
  input clk,
  input reset,
  input start_mat_mul,
  output done_mat_mul,

  input [`AWIDTH-1:0] address_mat_a,
  input [`AWIDTH-1:0] address_mat_b,
  input [`AWIDTH-1:0] address_mat_c,
  input [`ADDR_STRIDE_WIDTH-1:0] address_stride_a,
  input [`ADDR_STRIDE_WIDTH-1:0] address_stride_b,
  input [`ADDR_STRIDE_WIDTH-1:0] address_stride_c,
  """.format(final_block_size))

  for i in range(num_of_bram):
    file.write("""
  input [`BB_MAT_MUL_SIZE*`DWIDTH-1:0] a_data_{0}_0,
  output [`AWIDTH-1:0] a_addr_{0}_0,
  input [`BB_MAT_MUL_SIZE*`DWIDTH-1:0] b_data_0_{0},
  output [`AWIDTH-1:0] b_addr_0_{0},
  """.format(i))
  
  for i in range(num_of_bram):
    file.write("""
  output [`BB_MAT_MUL_SIZE*`DWIDTH-1:0] c_data_{0}_{1},
  output [`AWIDTH-1:0] c_addr_{0}_{1},
  output c_data_{0}_{1}_available,
    """.format(num_of_bram-1,i))

  file.write("""
  input [`MASK_WIDTH-1:0] validity_mask_a_rows,
  input [`MASK_WIDTH-1:0] validity_mask_a_cols_b_rows,
  input [`MASK_WIDTH-1:0] validity_mask_b_cols
);
  """)
  
  file.write('  /////////////////////////////////////////////////\n'
  	     '  // ORing all done signals\n'
  	     '  /////////////////////////////////////////////////\n')
  for i in range(num_of_bram):
    for j in range(num_of_bram):
      file.write('  wire done_mat_mul_{0}_{1};\n'.format(i, j))
  file.write('\n')
  file.write('  assign done_mat_mul = ')
  for i in range(num_of_bram):
    for j in range(num_of_bram):
      if (i == num_of_bram-1) and (j == num_of_bram-1):
        file.write('  done_mat_mul_{0}_{1};\n'.format(i, j))
      else:
        file.write('  done_mat_mul_{0}_{1} || '.format(i, j))
  
  #instaniate 4x4 matmul
  for i in range(num_of_bram):
    for j in range(num_of_bram):
      file.write('  /////////////////////////////////////////////////\n'
  		 '  // Matmul {0}_{1}\n'
  		 '  /////////////////////////////////////////////////\n\n'.format(i, j))
      #declare wire
      file.write('  wire [`BB_MAT_MUL_SIZE*`DWIDTH-1:0] a_data_{a}_{b}_to_{a}_{c};\n'
  		 '  wire [`BB_MAT_MUL_SIZE*`DWIDTH-1:0] b_data_{a}_{b}_to_{d}_{b};\n'.format(a=i,b=j,c=j+1,d=i+1))
  
      if(j != 0):
        file.write('  wire [`AWIDTH-1:0] a_addr_{0}_{1}_NC;\n'.format(i, j))
      if(i != 0):
        file.write('  wire [`AWIDTH-1:0] b_addr_{0}_{1}_NC;\n'.format(i, j))
  
      if(j != 0):
        file.write('  wire [`BB_MAT_MUL_SIZE*`DWIDTH-1:0] a_data_{0}_{1}_NC;\n'.format(i,j))
      if(i != 0):
        file.write('  wire [`BB_MAT_MUL_SIZE*`DWIDTH-1:0] b_data_{0}_{1}_NC;\n'.format(i,j))
  
      if(j == 0):
        file.write('  wire [`BB_MAT_MUL_SIZE*`DWIDTH-1:0] a_data_in_{0}_{1}_NC;\n'.format(i,j))
      if(i == 0):
        file.write('  wire [`BB_MAT_MUL_SIZE*`DWIDTH-1:0] b_data_in_{0}_{1}_NC;\n'.format(i,j))
        file.write('  wire [`BB_MAT_MUL_SIZE*`DWIDTH-1:0] c_data_in_{0}_{1}_NC;\n'.format(i,j))
  
      if(i != num_of_bram - 1):
        file.write('  wire [`BB_MAT_MUL_SIZE*`DWIDTH-1:0] c_data_{a}_{b}_to_{c}_{d};\n'.format(a = i, b = j, c = i+1, d =j))
        file.write('  wire [`AWIDTH-1:0] c_addr_{a}_{b}_NC;\n'.format(a = i, b = j))

      if(i != num_of_bram - 1):
        file.write('  wire c_data_{a}_{b}_available_NC;\n'.format(a = i, b = j))
  
      #instantiate the basic building block matmul
      #tt = int((i * num_of_bram + j)/4)
      file.write('\n')
      file.write('matmul_{c}x{c}_systolic u_matmul_{c}x{c}_systolic_{a}_{b}(\n'
  		 '  .clk(clk),\n'
  		 '  .reset(reset),\n'
  		 '  .start_mat_mul(start_mat_mul),\n'
  		 '  .done_mat_mul(done_mat_mul_{a}_{b}),'.format(a = i, b = j, c = basic_block_size))

      file.write("""
  .address_mat_a(address_mat_a),
  .address_mat_b(address_mat_b),
  .address_mat_c(address_mat_c),
  .address_stride_a(address_stride_a),
  .address_stride_b(address_stride_b),
  .address_stride_c(address_stride_c),\n""")
  
      if(j == 0):
        file.write('  .a_data(a_data_{0}_{1}),\n'.format(i,j))
      else:
        file.write('  .a_data(a_data_{0}_{1}_NC),\n'.format(i,j))
  
      if(i == 0):
        file.write('  .b_data(b_data_{0}_{1}),\n'.format(i, j))
      else:
        file.write('  .b_data(b_data_{0}_{1}_NC),\n'.format(i,j))
  
      if(j == 0):
        file.write('  .a_data_in(a_data_in_{0}_{1}_NC),\n'.format(i,j))
      else:
        file.write('  .a_data_in(a_data_{0}_{2}_to_{0}_{1}),\n'.format(i,j,j-1))
  
      if(i == 0):
        file.write('  .b_data_in(b_data_in_{0}_{1}_NC),\n'.format(i,j))
      else:
        file.write('  .b_data_in(b_data_{2}_{1}_to_{0}_{1}),\n'.format(i,j,i-1))
  
      if(i == 0):
        file.write('  .c_data_in(c_data_in_{0}_{1}_NC),\n'.format(i,j))
      else:
        file.write('  .c_data_in(c_data_{2}_{1}_to_{0}_{1}),\n'.format(i,j,i-1))
  
      if(i == num_of_bram - 1):
        file.write('  .c_data_out(c_data_{0}_{1}),\n'.format(i,j))
      else:
        file.write('  .c_data_out(c_data_{a}_{b}_to_{c}_{d}),\n'.format(a = i, b = j, c = i+1, d = j))

      file.write(  '  .a_data_out(a_data_{a}_{b}_to_{a}_{c}),\n'
  					'  .b_data_out(b_data_{a}_{b}_to_{d}_{b}),\n'
  		 			.format(a=i, b=j, c=j+1, d=i+1))
  
      if(j != 0):
        file.write('  .a_addr(a_addr_{0}_{1}_NC),\n'.format(i, j))
      else:
        file.write('  .a_addr(a_addr_{0}_{1}),\n'.format(i, j))
  
      if(i != 0):
        file.write('  .b_addr(b_addr_{0}_{1}_NC),\n'.format(i, j))
      else:
        file.write('  .b_addr(b_addr_{0}_{1}),\n'.format(i, j))

      if(i == num_of_bram - 1):
        file.write('  .c_addr(c_addr_{0}_{1}),\n'.format(i, j))
      else:
        file.write('  .c_addr(c_addr_{0}_{1}_NC),\n'.format(i, j))

      if(i == num_of_bram - 1):
        file.write('  .c_data_available(c_data_{0}_{1}_available),\n'.format(i,j))
      else:
        file.write('  .c_data_available(c_data_{a}_{b}_available_NC),\n'.format(a = i, b = j))
  
      file.write("""
  .validity_mask_a_rows(validity_mask_a_rows),
  .validity_mask_a_cols_b_rows(validity_mask_a_cols_b_rows),
  .validity_mask_b_cols(validity_mask_b_cols),""")

  		#Sep 1
  		#file.write(	'  .c_addr(c_addr_{0}_{1}),\n'
      file.write(	'\n  .final_mat_mul_size(8\'d{2}),\n'
  					'  .a_loc(8\'d{0}),\n'
  					'  .b_loc(8\'d{1})\n'
  					');\n\n'
  					.format(i, j, final_block_size))
  
  file.write('endmodule\n\n')

def write_ram_module(file):
  file.write("""
//////////////////////////////////
//Dual port RAM
//////////////////////////////////
module ram (
        addr0, 
        d0, 
        we0, 
        q0,  
        addr1,
        d1,
        we1,
        q1,
        clk);

input [`AWIDTH-1:0] addr0;
input [`AWIDTH-1:0] addr1;
input [`MASK_WIDTH*`DWIDTH-1:0] d0;
input [`MASK_WIDTH*`DWIDTH-1:0] d1;
input [`MASK_WIDTH-1:0] we0;
input [`MASK_WIDTH-1:0] we1;
output reg [`MASK_WIDTH*`DWIDTH-1:0] q0;
output reg [`MASK_WIDTH*`DWIDTH-1:0] q1;
input clk;

`ifdef VCS
reg [7:0] ram[((1<<`AWIDTH)-1):0];
integer i;

always @(posedge clk)  
begin 
    for (i = 0; i < `MASK_WIDTH; i=i+1) begin
        if (we0[i]) ram[addr0+i] <= d0[i*`DWIDTH +: `DWIDTH]; 
    end    
    for (i = 0; i < `MASK_WIDTH; i=i+1) begin
        q0[i*`DWIDTH +: `DWIDTH] <= ram[addr0+i];
    end    
end

always @(posedge clk)  
begin 
    for (i = 0; i < `MASK_WIDTH; i=i+1) begin
        if (we1[i]) ram[addr0+i] <= d1[i*`DWIDTH +: `DWIDTH]; 
    end    
    for (i = 0; i < `MASK_WIDTH; i=i+1) begin
        q1[i*`DWIDTH +: `DWIDTH] <= ram[addr1+i];
    end    
end

`else
//BRAMs available in VTR FPGA architectures have one bit write-enables.
//So let's combine multiple bits into 1. We don't have a usecase of
//writing/not-writing only parts of the word anyway.
wire we0_coalesced;
assign we0_coalesced = |we0;
wire we1_coalesced;
assign we1_coalesced = |we1;

dual_port_ram u_dual_port_ram(
.addr1(addr0),
.we1(we0_coalesced),
.data1(d0),
.out1(q0),
.addr2(addr1),
.we2(we1_coalesced),
.data2(d1),
.out2(q1),
.clk(clk)
);

`endif


endmodule

  """)

def main():
  parser = argparse.ArgumentParser()
  parser.add_argument("-b",
                      "--building_block",
                      action='store',
                      type=int,
                      default=4,
                      help='size of building block (should be a power of 2)')
  parser.add_argument("-f",
                      "--final_size",
                      action='store',
                      type=int,
                      default=8,
                      help='size of the final matmul (should be a power of 2)')
  parser.add_argument("-o",
                      "--outfile",
                      action='store',
                      default='out.v',
                      help='name of the output file')
  parser.add_argument("-nr",
                      "--no_ram",
                      action='store_true',
                      default=False,
                      help='do you want to dump code without ram instantiations')
  args = parser.parse_args()
  basic_block_size = args.building_block
  final_block_size = args.final_size
  output_filename = args.outfile
  with_ram = not(args.no_ram)
  
  try:
    file = open(output_filename, 'w+')
  except:
    print('faild to create the file ' + output_filename)
    exit(1)
  
  #write the definition
  file.write("""
`timescale 1ns/1ns
`define DWIDTH {}
`define AWIDTH {}
`define MEM_SIZE {}

`define MAT_MUL_SIZE {}
`define MASK_WIDTH {}
`define LOG2_MAT_MUL_SIZE {}
`define BB_MAT_MUL_SIZE `MAT_MUL_SIZE
`define NUM_CYCLES_IN_MAC 3
`define MEM_ACCESS_LATENCY 1
`define REG_DATAWIDTH 32
`define REG_ADDRWIDTH 8
`define ADDR_STRIDE_WIDTH 8

`define REG_START_DONE_ADDR 32'h0
`define REG_MATRIX_A_ADDR 32'he
`define REG_MATRIX_B_ADDR 32'h12
`define REG_MATRIX_C_ADDR 32'h16
`define REG_VALID_MASK_ADDR 32'h20
`define REG_MATRIX_A_STRIDE_ADDR 32'h28
`define REG_MATRIX_B_STRIDE_ADDR 32'h32
`define REG_MATRIX_C_STRIDE_ADDR 32'h36
  """.format(data_width, address_width, mem_size, basic_block_size, basic_block_size, str(int(math.log2(basic_block_size)))))
  
  #with bram module
  if(with_ram == True):
    write_with_ram(file, basic_block_size, final_block_size)
  
  write_systolic_matmul(file, basic_block_size, final_block_size)

  if(with_ram == True):
    write_ram_module(file)
  file.close()

main()