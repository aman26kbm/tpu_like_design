
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020-07-13 23:36:08.461498
// Design Name: 
// Module Name: matmul_16x16
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module matmul(
 clk,
 reset,
 start_mat_mul,
 done_mat_mul,
 address_mat_a,
 address_mat_b,
 address_mat_c,
 address_stride_a,
 address_stride_b,
 address_stride_c,
 a_data,
 b_data,
 a_data_in, //Data values coming in from previous matmul - systolic connections
 b_data_in,
 c_data_in, //Data values coming in from previous matmul - systolic shifting
 c_data_out, //Data values going out to next matmul - systolic shifting
 a_data_out,
 b_data_out,
 a_addr,
 b_addr,
 c_addr,
 c_data_available,

 save_output_to_accum,
 add_accum_to_output,
  
 enable_conv_mode,
 conv_filter_height,
 conv_filter_width,
 conv_stride_horiz,
 conv_stride_verti,
 conv_padding_left,
 conv_padding_right,
 conv_padding_top,
 conv_padding_bottom,
 num_channels_inp,
 num_channels_out,
 inp_img_height,
 inp_img_width,
 out_img_height,
 out_img_width,
 batch_size,
  
 validity_mask_a_rows,
 validity_mask_a_cols_b_rows,
 validity_mask_b_cols,
  
final_mat_mul_size,
  
 a_loc,
 b_loc
);

 input clk;
 input reset;
 input start_mat_mul;
 output done_mat_mul;
 input [`AWIDTH-1:0] address_mat_a;
 input [`AWIDTH-1:0] address_mat_b;
 input [`AWIDTH-1:0] address_mat_c;
 input [`ADDR_STRIDE_WIDTH-1:0] address_stride_a;
 input [`ADDR_STRIDE_WIDTH-1:0] address_stride_b;
 input [`ADDR_STRIDE_WIDTH-1:0] address_stride_c;
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

 input save_output_to_accum;
 input add_accum_to_output;
  
 input enable_conv_mode;
 input [3:0] conv_filter_height;
 input [3:0] conv_filter_width;
 input [3:0] conv_stride_horiz;
 input [3:0] conv_stride_verti;
 input [3:0] conv_padding_left;
 input [3:0] conv_padding_right;
 input [3:0] conv_padding_top;
 input [3:0] conv_padding_bottom;
 input [15:0] num_channels_inp;
 input [15:0] num_channels_out;
 input [15:0] inp_img_height;
 input [15:0] inp_img_width;
 input [15:0] out_img_height;
 input [15:0] out_img_width;
 input [31:0] batch_size;
  
 input [`MASK_WIDTH-1:0] validity_mask_a_rows;
 input [`MASK_WIDTH-1:0] validity_mask_a_cols_b_rows;
 input [`MASK_WIDTH-1:0] validity_mask_b_cols;

//7:0 is okay here. We aren't going to make a matmul larger than 128x128
//In fact, these will get optimized out by the synthesis tool, because
//we hardcode them at the instantiation level.
 input [7:0] final_mat_mul_size;
  
 input [7:0] a_loc;
 input [7:0] b_loc;

//////////////////////////////////////////////////////////////////////////
// Logic for clock counting and when to assert done
//////////////////////////////////////////////////////////////////////////

reg done_mat_mul;
//This is 7 bits because the expectation is that clock count will be pretty
//small. For large matmuls, this will need to increased to have more bits.
//In general, a systolic multiplier takes 4*N-2+P cycles, where N is the size 
//of the matmul and P is the number of pipleine stages in the MAC block.
reg [7:0] clk_cnt;

//Finding out number of cycles to assert matmul done.
//When we have to save the outputs to accumulators, then we don't need to
//shift out data. So, we can assert done_mat_mul early.
//In the normal case, we have to include the time to shift out the results. 
//Note: the count expression used to contain "4*final_mat_mul_size", but 
//to avoid multiplication, we now use "final_mat_mul_size<<2"
wire [7:0] clk_cnt_for_done;

assign clk_cnt_for_done = 
                          (save_output_to_accum && add_accum_to_output) ?
                          ((final_mat_mul_size<<2) - 3 + `NUM_CYCLES_IN_MAC - final_mat_mul_size) : (
                          (save_output_to_accum) ?
                          ((final_mat_mul_size<<2) - 3 + `NUM_CYCLES_IN_MAC - final_mat_mul_size) : (
                          (add_accum_to_output) ? 
                          ((final_mat_mul_size<<2) - 3 + `NUM_CYCLES_IN_MAC) :  
                          ((final_mat_mul_size<<2) - 3 + `NUM_CYCLES_IN_MAC) ));  
    
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


//////////////////////////////////////////////////////////////////////////
// Logic to keep track of c,r,s values during convolution
//////////////////////////////////////////////////////////////////////////
reg [3:0] r; //iterator for filter height
reg [3:0] s; //iterator for filter width
reg [15:0] c; //iterator for input channels
reg [15:0] cur_c_saved;
reg [3:0] cur_r_saved;
reg [3:0] cur_s_saved;
reg dummy;

always @(posedge clk) begin
  
  if (reset || (add_accum_to_output && ~save_output_to_accum && done_mat_mul)) begin
    
    c <= 0;
    r <= 0;
    s <= 0;
  end
  else if (~start_mat_mul) begin
    //Dummy statements to make ODIN happy
    dummy <= conv_stride_horiz | conv_stride_verti | (|out_img_height) | (|out_img_width) | (|batch_size);
  end
  //Note than a_loc or b_loc doesn't matter in the code below. A and B are always synchronized.
  //else if ((clk_cnt >= a_loc*`MAT_MUL_SIZE) && (clk_cnt < a_loc*`MAT_MUL_SIZE+final_mat_mul_size)) begin
  //Writing the line above to avoid multiplication:
  
  else if ((clk_cnt >= (a_loc<<`LOG2_MAT_MUL_SIZE)) && (clk_cnt < (a_loc<<`LOG2_MAT_MUL_SIZE)+final_mat_mul_size)) begin
    
    if (enable_conv_mode) begin
      if (s < (conv_filter_width-1)) begin
          s <= s + 1;
      end else begin
          s <= 0;
      end 

      if (s == (conv_filter_width-1)) begin
          if (r == (conv_filter_height-1)) begin
              r <= 0;
          end else begin
              r <= r + 1;
          end
      end 

      if ((r == (conv_filter_height-1)) && (s == (conv_filter_width-1))) begin
          if (c == (num_channels_inp-1)) begin
              c <= 0;
          end else begin
              c <= c + 1;
          end
      end
    end
  end
end  

//////////////////////////////////////////////////////////////////////////
// Logic to generate addresses to BRAM A
//////////////////////////////////////////////////////////////////////////
reg [`AWIDTH-1:0] a_addr;
reg a_mem_access; //flag that tells whether the matmul is trying to access memory or not

always @(posedge clk) begin
  //(clk_cnt >= a_loc*`MAT_MUL_SIZE+final_mat_mul_size) begin
  //Writing the line above to avoid multiplication:

  if (reset || ~start_mat_mul || (clk_cnt >= (a_loc<<`LOG2_MAT_MUL_SIZE)+final_mat_mul_size)) begin
  
    if (enable_conv_mode) begin
      a_addr <= address_mat_a;
    end 
    else begin
      a_addr <= address_mat_a-address_stride_a;
    end
  
    a_mem_access <= 0;
  end
  //else if ((clk_cnt >= a_loc*`MAT_MUL_SIZE) && (clk_cnt < a_loc*`MAT_MUL_SIZE+final_mat_mul_size)) begin
  //Writing the line above to avoid multiplication:

  else if ((clk_cnt >= (a_loc<<`LOG2_MAT_MUL_SIZE)) && (clk_cnt < (a_loc<<`LOG2_MAT_MUL_SIZE)+final_mat_mul_size)) begin
  
    if (enable_conv_mode) begin
      a_addr <= address_mat_a + s + r * (inp_img_width+conv_padding_left+conv_padding_right) + c * (inp_img_width+conv_padding_left+conv_padding_right) * (inp_img_height+conv_padding_top+conv_padding_bottom);
    end
    else begin
      a_addr <= a_addr + address_stride_a;
    end
  
    a_mem_access <= 1;
  end
end

//////////////////////////////////////////////////////////////////////////
// Logic to generate valid signals for data coming from BRAM A
//////////////////////////////////////////////////////////////////////////
reg [7:0] a_mem_access_counter;
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

wire a_data_valid; //flag that tells whether the data from memory is valid
assign a_data_valid = 
     ((validity_mask_a_cols_b_rows[0]==1'b0 && a_mem_access_counter==0) ||
      (validity_mask_a_cols_b_rows[1]==1'b0 && a_mem_access_counter==1) ||
      (validity_mask_a_cols_b_rows[2]==1'b0 && a_mem_access_counter==2) ||
      (validity_mask_a_cols_b_rows[3]==1'b0 && a_mem_access_counter==3) ||
      (validity_mask_a_cols_b_rows[4]==1'b0 && a_mem_access_counter==4) ||
      (validity_mask_a_cols_b_rows[5]==1'b0 && a_mem_access_counter==5) ||
      (validity_mask_a_cols_b_rows[6]==1'b0 && a_mem_access_counter==6) ||
      (validity_mask_a_cols_b_rows[7]==1'b0 && a_mem_access_counter==7) ||
      (validity_mask_a_cols_b_rows[8]==1'b0 && a_mem_access_counter==8) ||
      (validity_mask_a_cols_b_rows[9]==1'b0 && a_mem_access_counter==9) ||
      (validity_mask_a_cols_b_rows[10]==1'b0 && a_mem_access_counter==10) ||
      (validity_mask_a_cols_b_rows[11]==1'b0 && a_mem_access_counter==11) ||
      (validity_mask_a_cols_b_rows[12]==1'b0 && a_mem_access_counter==12) ||
      (validity_mask_a_cols_b_rows[13]==1'b0 && a_mem_access_counter==13) ||
      (validity_mask_a_cols_b_rows[14]==1'b0 && a_mem_access_counter==14) ||
      (validity_mask_a_cols_b_rows[15]==1'b0 && a_mem_access_counter==15)) ?
    
    1'b0 : (a_mem_access_counter >= `MEM_ACCESS_LATENCY);

//////////////////////////////////////////////////////////////////////////
// Logic to delay certain parts of the data received from BRAM A (systolic data setup)
//////////////////////////////////////////////////////////////////////////
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

assign a0_data = a_data[1*`DWIDTH-1:0*`DWIDTH] & {`DWIDTH{a_data_valid}} & {`DWIDTH{validity_mask_a_rows[0]}};
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

assign a0_data_in = a_data_in[1*`DWIDTH-1:0*`DWIDTH];
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
  a3_data_delayed_1 <= a3_data;
  a4_data_delayed_1 <= a4_data;
  a5_data_delayed_1 <= a5_data;
  a6_data_delayed_1 <= a6_data;
  a7_data_delayed_1 <= a7_data;
  a8_data_delayed_1 <= a8_data;
  a9_data_delayed_1 <= a9_data;
  a10_data_delayed_1 <= a10_data;
  a11_data_delayed_1 <= a11_data;
  a12_data_delayed_1 <= a12_data;
  a13_data_delayed_1 <= a13_data;
  a14_data_delayed_1 <= a14_data;
  a15_data_delayed_1 <= a15_data;
  a2_data_delayed_2 <= a2_data_delayed_1;
  a3_data_delayed_2 <= a3_data_delayed_1;
  a3_data_delayed_3 <= a3_data_delayed_2;
  a4_data_delayed_2 <= a4_data_delayed_1;
  a4_data_delayed_3 <= a4_data_delayed_2;
  a4_data_delayed_4 <= a4_data_delayed_3;
  a5_data_delayed_2 <= a5_data_delayed_1;
  a5_data_delayed_3 <= a5_data_delayed_2;
  a5_data_delayed_4 <= a5_data_delayed_3;
  a5_data_delayed_5 <= a5_data_delayed_4;
  a6_data_delayed_2 <= a6_data_delayed_1;
  a6_data_delayed_3 <= a6_data_delayed_2;
  a6_data_delayed_4 <= a6_data_delayed_3;
  a6_data_delayed_5 <= a6_data_delayed_4;
  a6_data_delayed_6 <= a6_data_delayed_5;
  a7_data_delayed_2 <= a7_data_delayed_1;
  a7_data_delayed_3 <= a7_data_delayed_2;
  a7_data_delayed_4 <= a7_data_delayed_3;
  a7_data_delayed_5 <= a7_data_delayed_4;
  a7_data_delayed_6 <= a7_data_delayed_5;
  a7_data_delayed_7 <= a7_data_delayed_6;
  a8_data_delayed_2 <= a8_data_delayed_1;
  a8_data_delayed_3 <= a8_data_delayed_2;
  a8_data_delayed_4 <= a8_data_delayed_3;
  a8_data_delayed_5 <= a8_data_delayed_4;
  a8_data_delayed_6 <= a8_data_delayed_5;
  a8_data_delayed_7 <= a8_data_delayed_6;
  a8_data_delayed_8 <= a8_data_delayed_7;
  a9_data_delayed_2 <= a9_data_delayed_1;
  a9_data_delayed_3 <= a9_data_delayed_2;
  a9_data_delayed_4 <= a9_data_delayed_3;
  a9_data_delayed_5 <= a9_data_delayed_4;
  a9_data_delayed_6 <= a9_data_delayed_5;
  a9_data_delayed_7 <= a9_data_delayed_6;
  a9_data_delayed_8 <= a9_data_delayed_7;
  a9_data_delayed_9 <= a9_data_delayed_8;
  a10_data_delayed_2 <= a10_data_delayed_1;
  a10_data_delayed_3 <= a10_data_delayed_2;
  a10_data_delayed_4 <= a10_data_delayed_3;
  a10_data_delayed_5 <= a10_data_delayed_4;
  a10_data_delayed_6 <= a10_data_delayed_5;
  a10_data_delayed_7 <= a10_data_delayed_6;
  a10_data_delayed_8 <= a10_data_delayed_7;
  a10_data_delayed_9 <= a10_data_delayed_8;
  a10_data_delayed_10 <= a10_data_delayed_9;
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
reg b_mem_access; //flag that tells whether the matmul is trying to access memory or not
always @(posedge clk) begin
  //else if (clk_cnt >= b_loc*`MAT_MUL_SIZE+final_mat_mul_size) begin
  //Writing the line above to avoid multiplication:

  if ((reset || ~start_mat_mul) || (clk_cnt >= (b_loc<<`LOG2_MAT_MUL_SIZE)+final_mat_mul_size)) begin

    if (enable_conv_mode) begin
      b_addr <= address_mat_b;
    end 
    else begin
      b_addr <= address_mat_b - address_stride_b;
    end
  
    b_mem_access <= 0;
  end
  //else if ((clk_cnt >= b_loc*`MAT_MUL_SIZE) && (clk_cnt < b_loc*`MAT_MUL_SIZE+final_mat_mul_size)) begin
  //Writing the line above to avoid multiplication:

  else if ((clk_cnt >= (b_loc<<`LOG2_MAT_MUL_SIZE)) && (clk_cnt < (b_loc<<`LOG2_MAT_MUL_SIZE)+final_mat_mul_size)) begin

    if (enable_conv_mode) begin
      b_addr <= address_mat_b + (s*num_channels_out) + (r*num_channels_out*num_channels_out) + (c*num_channels_out*num_channels_out*num_channels_out);
    end
    else begin
      b_addr <= b_addr + address_stride_b;
    end
  
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

wire b_data_valid; //flag that tells whether the data from memory is valid
assign b_data_valid = 
     ((validity_mask_a_cols_b_rows[0]==1'b0 && b_mem_access_counter==0) ||
      (validity_mask_a_cols_b_rows[1]==1'b0 && b_mem_access_counter==1) ||
      (validity_mask_a_cols_b_rows[2]==1'b0 && b_mem_access_counter==2) ||
      (validity_mask_a_cols_b_rows[3]==1'b0 && b_mem_access_counter==3) ||
      (validity_mask_a_cols_b_rows[4]==1'b0 && b_mem_access_counter==4) ||
      (validity_mask_a_cols_b_rows[5]==1'b0 && b_mem_access_counter==5) ||
      (validity_mask_a_cols_b_rows[6]==1'b0 && b_mem_access_counter==6) ||
      (validity_mask_a_cols_b_rows[7]==1'b0 && b_mem_access_counter==7) ||
      (validity_mask_a_cols_b_rows[8]==1'b0 && b_mem_access_counter==8) ||
      (validity_mask_a_cols_b_rows[9]==1'b0 && b_mem_access_counter==9) ||
      (validity_mask_a_cols_b_rows[10]==1'b0 && b_mem_access_counter==10) ||
      (validity_mask_a_cols_b_rows[11]==1'b0 && b_mem_access_counter==11) ||
      (validity_mask_a_cols_b_rows[12]==1'b0 && b_mem_access_counter==12) ||
      (validity_mask_a_cols_b_rows[13]==1'b0 && b_mem_access_counter==13) ||
      (validity_mask_a_cols_b_rows[14]==1'b0 && b_mem_access_counter==14) ||
      (validity_mask_a_cols_b_rows[15]==1'b0 && b_mem_access_counter==15)) ?
    
        1'b0 : (b_mem_access_counter >= `MEM_ACCESS_LATENCY);

//////////////////////////////////////////////////////////////////////////
// Logic to delay certain parts of the data received from BRAM B (systolic data setup)
//////////////////////////////////////////////////////////////////////////
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

assign b0_data = b_data[1*`DWIDTH-1:0*`DWIDTH] & {`DWIDTH{b_data_valid}} & {`DWIDTH{validity_mask_b_cols[0]}};
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

assign b0_data_in = b_data_in[1*`DWIDTH-1:0*`DWIDTH];
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
  b3_data_delayed_1 <= b3_data;
  b4_data_delayed_1 <= b4_data;
  b5_data_delayed_1 <= b5_data;
  b6_data_delayed_1 <= b6_data;
  b7_data_delayed_1 <= b7_data;
  b8_data_delayed_1 <= b8_data;
  b9_data_delayed_1 <= b9_data;
  b10_data_delayed_1 <= b10_data;
  b11_data_delayed_1 <= b11_data;
  b12_data_delayed_1 <= b12_data;
  b13_data_delayed_1 <= b13_data;
  b14_data_delayed_1 <= b14_data;
  b15_data_delayed_1 <= b15_data;
  b2_data_delayed_2 <= b2_data_delayed_1;
  b3_data_delayed_2 <= b3_data_delayed_1;
  b3_data_delayed_3 <= b3_data_delayed_2;
  b4_data_delayed_2 <= b4_data_delayed_1;
  b4_data_delayed_3 <= b4_data_delayed_2;
  b4_data_delayed_4 <= b4_data_delayed_3;
  b5_data_delayed_2 <= b5_data_delayed_1;
  b5_data_delayed_3 <= b5_data_delayed_2;
  b5_data_delayed_4 <= b5_data_delayed_3;
  b5_data_delayed_5 <= b5_data_delayed_4;
  b6_data_delayed_2 <= b6_data_delayed_1;
  b6_data_delayed_3 <= b6_data_delayed_2;
  b6_data_delayed_4 <= b6_data_delayed_3;
  b6_data_delayed_5 <= b6_data_delayed_4;
  b6_data_delayed_6 <= b6_data_delayed_5;
  b7_data_delayed_2 <= b7_data_delayed_1;
  b7_data_delayed_3 <= b7_data_delayed_2;
  b7_data_delayed_4 <= b7_data_delayed_3;
  b7_data_delayed_5 <= b7_data_delayed_4;
  b7_data_delayed_6 <= b7_data_delayed_5;
  b7_data_delayed_7 <= b7_data_delayed_6;
  b8_data_delayed_2 <= b8_data_delayed_1;
  b8_data_delayed_3 <= b8_data_delayed_2;
  b8_data_delayed_4 <= b8_data_delayed_3;
  b8_data_delayed_5 <= b8_data_delayed_4;
  b8_data_delayed_6 <= b8_data_delayed_5;
  b8_data_delayed_7 <= b8_data_delayed_6;
  b8_data_delayed_8 <= b8_data_delayed_7;
  b9_data_delayed_2 <= b9_data_delayed_1;
  b9_data_delayed_3 <= b9_data_delayed_2;
  b9_data_delayed_4 <= b9_data_delayed_3;
  b9_data_delayed_5 <= b9_data_delayed_4;
  b9_data_delayed_6 <= b9_data_delayed_5;
  b9_data_delayed_7 <= b9_data_delayed_6;
  b9_data_delayed_8 <= b9_data_delayed_7;
  b9_data_delayed_9 <= b9_data_delayed_8;
  b10_data_delayed_2 <= b10_data_delayed_1;
  b10_data_delayed_3 <= b10_data_delayed_2;
  b10_data_delayed_4 <= b10_data_delayed_3;
  b10_data_delayed_5 <= b10_data_delayed_4;
  b10_data_delayed_6 <= b10_data_delayed_5;
  b10_data_delayed_7 <= b10_data_delayed_6;
  b10_data_delayed_8 <= b10_data_delayed_7;
  b10_data_delayed_9 <= b10_data_delayed_8;
  b10_data_delayed_10 <= b10_data_delayed_9;
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
wire [`DWIDTH-1:0] cin_row0;
wire [`DWIDTH-1:0] cin_row1;
wire [`DWIDTH-1:0] cin_row2;
wire [`DWIDTH-1:0] cin_row3;
wire [`DWIDTH-1:0] cin_row4;
wire [`DWIDTH-1:0] cin_row5;
wire [`DWIDTH-1:0] cin_row6;
wire [`DWIDTH-1:0] cin_row7;
wire [`DWIDTH-1:0] cin_row8;
wire [`DWIDTH-1:0] cin_row9;
wire [`DWIDTH-1:0] cin_row10;
wire [`DWIDTH-1:0] cin_row11;
wire [`DWIDTH-1:0] cin_row12;
wire [`DWIDTH-1:0] cin_row13;
wire [`DWIDTH-1:0] cin_row14;
wire [`DWIDTH-1:0] cin_row15;
wire row_latch_en;

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
assign cin_row0 = c_data_in[1*`DWIDTH-1:0*`DWIDTH];
assign cin_row1 = c_data_in[2*`DWIDTH-1:1*`DWIDTH];
assign cin_row2 = c_data_in[3*`DWIDTH-1:2*`DWIDTH];
assign cin_row3 = c_data_in[4*`DWIDTH-1:3*`DWIDTH];
assign cin_row4 = c_data_in[5*`DWIDTH-1:4*`DWIDTH];
assign cin_row5 = c_data_in[6*`DWIDTH-1:5*`DWIDTH];
assign cin_row6 = c_data_in[7*`DWIDTH-1:6*`DWIDTH];
assign cin_row7 = c_data_in[8*`DWIDTH-1:7*`DWIDTH];
assign cin_row8 = c_data_in[9*`DWIDTH-1:8*`DWIDTH];
assign cin_row9 = c_data_in[10*`DWIDTH-1:9*`DWIDTH];
assign cin_row10 = c_data_in[11*`DWIDTH-1:10*`DWIDTH];
assign cin_row11 = c_data_in[12*`DWIDTH-1:11*`DWIDTH];
assign cin_row12 = c_data_in[13*`DWIDTH-1:12*`DWIDTH];
assign cin_row13 = c_data_in[14*`DWIDTH-1:13*`DWIDTH];
assign cin_row14 = c_data_in[15*`DWIDTH-1:14*`DWIDTH];
assign cin_row15 = c_data_in[16*`DWIDTH-1:15*`DWIDTH];
wire [`DWIDTH-1:0] matrixC0_0_added;
wire [`DWIDTH-1:0] matrixC0_1_added;
wire [`DWIDTH-1:0] matrixC0_2_added;
wire [`DWIDTH-1:0] matrixC0_3_added;
wire [`DWIDTH-1:0] matrixC0_4_added;
wire [`DWIDTH-1:0] matrixC0_5_added;
wire [`DWIDTH-1:0] matrixC0_6_added;
wire [`DWIDTH-1:0] matrixC0_7_added;
wire [`DWIDTH-1:0] matrixC0_8_added;
wire [`DWIDTH-1:0] matrixC0_9_added;
wire [`DWIDTH-1:0] matrixC0_10_added;
wire [`DWIDTH-1:0] matrixC0_11_added;
wire [`DWIDTH-1:0] matrixC0_12_added;
wire [`DWIDTH-1:0] matrixC0_13_added;
wire [`DWIDTH-1:0] matrixC0_14_added;
wire [`DWIDTH-1:0] matrixC0_15_added;
wire [`DWIDTH-1:0] matrixC1_0_added;
wire [`DWIDTH-1:0] matrixC1_1_added;
wire [`DWIDTH-1:0] matrixC1_2_added;
wire [`DWIDTH-1:0] matrixC1_3_added;
wire [`DWIDTH-1:0] matrixC1_4_added;
wire [`DWIDTH-1:0] matrixC1_5_added;
wire [`DWIDTH-1:0] matrixC1_6_added;
wire [`DWIDTH-1:0] matrixC1_7_added;
wire [`DWIDTH-1:0] matrixC1_8_added;
wire [`DWIDTH-1:0] matrixC1_9_added;
wire [`DWIDTH-1:0] matrixC1_10_added;
wire [`DWIDTH-1:0] matrixC1_11_added;
wire [`DWIDTH-1:0] matrixC1_12_added;
wire [`DWIDTH-1:0] matrixC1_13_added;
wire [`DWIDTH-1:0] matrixC1_14_added;
wire [`DWIDTH-1:0] matrixC1_15_added;
wire [`DWIDTH-1:0] matrixC2_0_added;
wire [`DWIDTH-1:0] matrixC2_1_added;
wire [`DWIDTH-1:0] matrixC2_2_added;
wire [`DWIDTH-1:0] matrixC2_3_added;
wire [`DWIDTH-1:0] matrixC2_4_added;
wire [`DWIDTH-1:0] matrixC2_5_added;
wire [`DWIDTH-1:0] matrixC2_6_added;
wire [`DWIDTH-1:0] matrixC2_7_added;
wire [`DWIDTH-1:0] matrixC2_8_added;
wire [`DWIDTH-1:0] matrixC2_9_added;
wire [`DWIDTH-1:0] matrixC2_10_added;
wire [`DWIDTH-1:0] matrixC2_11_added;
wire [`DWIDTH-1:0] matrixC2_12_added;
wire [`DWIDTH-1:0] matrixC2_13_added;
wire [`DWIDTH-1:0] matrixC2_14_added;
wire [`DWIDTH-1:0] matrixC2_15_added;
wire [`DWIDTH-1:0] matrixC3_0_added;
wire [`DWIDTH-1:0] matrixC3_1_added;
wire [`DWIDTH-1:0] matrixC3_2_added;
wire [`DWIDTH-1:0] matrixC3_3_added;
wire [`DWIDTH-1:0] matrixC3_4_added;
wire [`DWIDTH-1:0] matrixC3_5_added;
wire [`DWIDTH-1:0] matrixC3_6_added;
wire [`DWIDTH-1:0] matrixC3_7_added;
wire [`DWIDTH-1:0] matrixC3_8_added;
wire [`DWIDTH-1:0] matrixC3_9_added;
wire [`DWIDTH-1:0] matrixC3_10_added;
wire [`DWIDTH-1:0] matrixC3_11_added;
wire [`DWIDTH-1:0] matrixC3_12_added;
wire [`DWIDTH-1:0] matrixC3_13_added;
wire [`DWIDTH-1:0] matrixC3_14_added;
wire [`DWIDTH-1:0] matrixC3_15_added;
wire [`DWIDTH-1:0] matrixC4_0_added;
wire [`DWIDTH-1:0] matrixC4_1_added;
wire [`DWIDTH-1:0] matrixC4_2_added;
wire [`DWIDTH-1:0] matrixC4_3_added;
wire [`DWIDTH-1:0] matrixC4_4_added;
wire [`DWIDTH-1:0] matrixC4_5_added;
wire [`DWIDTH-1:0] matrixC4_6_added;
wire [`DWIDTH-1:0] matrixC4_7_added;
wire [`DWIDTH-1:0] matrixC4_8_added;
wire [`DWIDTH-1:0] matrixC4_9_added;
wire [`DWIDTH-1:0] matrixC4_10_added;
wire [`DWIDTH-1:0] matrixC4_11_added;
wire [`DWIDTH-1:0] matrixC4_12_added;
wire [`DWIDTH-1:0] matrixC4_13_added;
wire [`DWIDTH-1:0] matrixC4_14_added;
wire [`DWIDTH-1:0] matrixC4_15_added;
wire [`DWIDTH-1:0] matrixC5_0_added;
wire [`DWIDTH-1:0] matrixC5_1_added;
wire [`DWIDTH-1:0] matrixC5_2_added;
wire [`DWIDTH-1:0] matrixC5_3_added;
wire [`DWIDTH-1:0] matrixC5_4_added;
wire [`DWIDTH-1:0] matrixC5_5_added;
wire [`DWIDTH-1:0] matrixC5_6_added;
wire [`DWIDTH-1:0] matrixC5_7_added;
wire [`DWIDTH-1:0] matrixC5_8_added;
wire [`DWIDTH-1:0] matrixC5_9_added;
wire [`DWIDTH-1:0] matrixC5_10_added;
wire [`DWIDTH-1:0] matrixC5_11_added;
wire [`DWIDTH-1:0] matrixC5_12_added;
wire [`DWIDTH-1:0] matrixC5_13_added;
wire [`DWIDTH-1:0] matrixC5_14_added;
wire [`DWIDTH-1:0] matrixC5_15_added;
wire [`DWIDTH-1:0] matrixC6_0_added;
wire [`DWIDTH-1:0] matrixC6_1_added;
wire [`DWIDTH-1:0] matrixC6_2_added;
wire [`DWIDTH-1:0] matrixC6_3_added;
wire [`DWIDTH-1:0] matrixC6_4_added;
wire [`DWIDTH-1:0] matrixC6_5_added;
wire [`DWIDTH-1:0] matrixC6_6_added;
wire [`DWIDTH-1:0] matrixC6_7_added;
wire [`DWIDTH-1:0] matrixC6_8_added;
wire [`DWIDTH-1:0] matrixC6_9_added;
wire [`DWIDTH-1:0] matrixC6_10_added;
wire [`DWIDTH-1:0] matrixC6_11_added;
wire [`DWIDTH-1:0] matrixC6_12_added;
wire [`DWIDTH-1:0] matrixC6_13_added;
wire [`DWIDTH-1:0] matrixC6_14_added;
wire [`DWIDTH-1:0] matrixC6_15_added;
wire [`DWIDTH-1:0] matrixC7_0_added;
wire [`DWIDTH-1:0] matrixC7_1_added;
wire [`DWIDTH-1:0] matrixC7_2_added;
wire [`DWIDTH-1:0] matrixC7_3_added;
wire [`DWIDTH-1:0] matrixC7_4_added;
wire [`DWIDTH-1:0] matrixC7_5_added;
wire [`DWIDTH-1:0] matrixC7_6_added;
wire [`DWIDTH-1:0] matrixC7_7_added;
wire [`DWIDTH-1:0] matrixC7_8_added;
wire [`DWIDTH-1:0] matrixC7_9_added;
wire [`DWIDTH-1:0] matrixC7_10_added;
wire [`DWIDTH-1:0] matrixC7_11_added;
wire [`DWIDTH-1:0] matrixC7_12_added;
wire [`DWIDTH-1:0] matrixC7_13_added;
wire [`DWIDTH-1:0] matrixC7_14_added;
wire [`DWIDTH-1:0] matrixC7_15_added;
wire [`DWIDTH-1:0] matrixC8_0_added;
wire [`DWIDTH-1:0] matrixC8_1_added;
wire [`DWIDTH-1:0] matrixC8_2_added;
wire [`DWIDTH-1:0] matrixC8_3_added;
wire [`DWIDTH-1:0] matrixC8_4_added;
wire [`DWIDTH-1:0] matrixC8_5_added;
wire [`DWIDTH-1:0] matrixC8_6_added;
wire [`DWIDTH-1:0] matrixC8_7_added;
wire [`DWIDTH-1:0] matrixC8_8_added;
wire [`DWIDTH-1:0] matrixC8_9_added;
wire [`DWIDTH-1:0] matrixC8_10_added;
wire [`DWIDTH-1:0] matrixC8_11_added;
wire [`DWIDTH-1:0] matrixC8_12_added;
wire [`DWIDTH-1:0] matrixC8_13_added;
wire [`DWIDTH-1:0] matrixC8_14_added;
wire [`DWIDTH-1:0] matrixC8_15_added;
wire [`DWIDTH-1:0] matrixC9_0_added;
wire [`DWIDTH-1:0] matrixC9_1_added;
wire [`DWIDTH-1:0] matrixC9_2_added;
wire [`DWIDTH-1:0] matrixC9_3_added;
wire [`DWIDTH-1:0] matrixC9_4_added;
wire [`DWIDTH-1:0] matrixC9_5_added;
wire [`DWIDTH-1:0] matrixC9_6_added;
wire [`DWIDTH-1:0] matrixC9_7_added;
wire [`DWIDTH-1:0] matrixC9_8_added;
wire [`DWIDTH-1:0] matrixC9_9_added;
wire [`DWIDTH-1:0] matrixC9_10_added;
wire [`DWIDTH-1:0] matrixC9_11_added;
wire [`DWIDTH-1:0] matrixC9_12_added;
wire [`DWIDTH-1:0] matrixC9_13_added;
wire [`DWIDTH-1:0] matrixC9_14_added;
wire [`DWIDTH-1:0] matrixC9_15_added;
wire [`DWIDTH-1:0] matrixC10_0_added;
wire [`DWIDTH-1:0] matrixC10_1_added;
wire [`DWIDTH-1:0] matrixC10_2_added;
wire [`DWIDTH-1:0] matrixC10_3_added;
wire [`DWIDTH-1:0] matrixC10_4_added;
wire [`DWIDTH-1:0] matrixC10_5_added;
wire [`DWIDTH-1:0] matrixC10_6_added;
wire [`DWIDTH-1:0] matrixC10_7_added;
wire [`DWIDTH-1:0] matrixC10_8_added;
wire [`DWIDTH-1:0] matrixC10_9_added;
wire [`DWIDTH-1:0] matrixC10_10_added;
wire [`DWIDTH-1:0] matrixC10_11_added;
wire [`DWIDTH-1:0] matrixC10_12_added;
wire [`DWIDTH-1:0] matrixC10_13_added;
wire [`DWIDTH-1:0] matrixC10_14_added;
wire [`DWIDTH-1:0] matrixC10_15_added;
wire [`DWIDTH-1:0] matrixC11_0_added;
wire [`DWIDTH-1:0] matrixC11_1_added;
wire [`DWIDTH-1:0] matrixC11_2_added;
wire [`DWIDTH-1:0] matrixC11_3_added;
wire [`DWIDTH-1:0] matrixC11_4_added;
wire [`DWIDTH-1:0] matrixC11_5_added;
wire [`DWIDTH-1:0] matrixC11_6_added;
wire [`DWIDTH-1:0] matrixC11_7_added;
wire [`DWIDTH-1:0] matrixC11_8_added;
wire [`DWIDTH-1:0] matrixC11_9_added;
wire [`DWIDTH-1:0] matrixC11_10_added;
wire [`DWIDTH-1:0] matrixC11_11_added;
wire [`DWIDTH-1:0] matrixC11_12_added;
wire [`DWIDTH-1:0] matrixC11_13_added;
wire [`DWIDTH-1:0] matrixC11_14_added;
wire [`DWIDTH-1:0] matrixC11_15_added;
wire [`DWIDTH-1:0] matrixC12_0_added;
wire [`DWIDTH-1:0] matrixC12_1_added;
wire [`DWIDTH-1:0] matrixC12_2_added;
wire [`DWIDTH-1:0] matrixC12_3_added;
wire [`DWIDTH-1:0] matrixC12_4_added;
wire [`DWIDTH-1:0] matrixC12_5_added;
wire [`DWIDTH-1:0] matrixC12_6_added;
wire [`DWIDTH-1:0] matrixC12_7_added;
wire [`DWIDTH-1:0] matrixC12_8_added;
wire [`DWIDTH-1:0] matrixC12_9_added;
wire [`DWIDTH-1:0] matrixC12_10_added;
wire [`DWIDTH-1:0] matrixC12_11_added;
wire [`DWIDTH-1:0] matrixC12_12_added;
wire [`DWIDTH-1:0] matrixC12_13_added;
wire [`DWIDTH-1:0] matrixC12_14_added;
wire [`DWIDTH-1:0] matrixC12_15_added;
wire [`DWIDTH-1:0] matrixC13_0_added;
wire [`DWIDTH-1:0] matrixC13_1_added;
wire [`DWIDTH-1:0] matrixC13_2_added;
wire [`DWIDTH-1:0] matrixC13_3_added;
wire [`DWIDTH-1:0] matrixC13_4_added;
wire [`DWIDTH-1:0] matrixC13_5_added;
wire [`DWIDTH-1:0] matrixC13_6_added;
wire [`DWIDTH-1:0] matrixC13_7_added;
wire [`DWIDTH-1:0] matrixC13_8_added;
wire [`DWIDTH-1:0] matrixC13_9_added;
wire [`DWIDTH-1:0] matrixC13_10_added;
wire [`DWIDTH-1:0] matrixC13_11_added;
wire [`DWIDTH-1:0] matrixC13_12_added;
wire [`DWIDTH-1:0] matrixC13_13_added;
wire [`DWIDTH-1:0] matrixC13_14_added;
wire [`DWIDTH-1:0] matrixC13_15_added;
wire [`DWIDTH-1:0] matrixC14_0_added;
wire [`DWIDTH-1:0] matrixC14_1_added;
wire [`DWIDTH-1:0] matrixC14_2_added;
wire [`DWIDTH-1:0] matrixC14_3_added;
wire [`DWIDTH-1:0] matrixC14_4_added;
wire [`DWIDTH-1:0] matrixC14_5_added;
wire [`DWIDTH-1:0] matrixC14_6_added;
wire [`DWIDTH-1:0] matrixC14_7_added;
wire [`DWIDTH-1:0] matrixC14_8_added;
wire [`DWIDTH-1:0] matrixC14_9_added;
wire [`DWIDTH-1:0] matrixC14_10_added;
wire [`DWIDTH-1:0] matrixC14_11_added;
wire [`DWIDTH-1:0] matrixC14_12_added;
wire [`DWIDTH-1:0] matrixC14_13_added;
wire [`DWIDTH-1:0] matrixC14_14_added;
wire [`DWIDTH-1:0] matrixC14_15_added;
wire [`DWIDTH-1:0] matrixC15_0_added;
wire [`DWIDTH-1:0] matrixC15_1_added;
wire [`DWIDTH-1:0] matrixC15_2_added;
wire [`DWIDTH-1:0] matrixC15_3_added;
wire [`DWIDTH-1:0] matrixC15_4_added;
wire [`DWIDTH-1:0] matrixC15_5_added;
wire [`DWIDTH-1:0] matrixC15_6_added;
wire [`DWIDTH-1:0] matrixC15_7_added;
wire [`DWIDTH-1:0] matrixC15_8_added;
wire [`DWIDTH-1:0] matrixC15_9_added;
wire [`DWIDTH-1:0] matrixC15_10_added;
wire [`DWIDTH-1:0] matrixC15_11_added;
wire [`DWIDTH-1:0] matrixC15_12_added;
wire [`DWIDTH-1:0] matrixC15_13_added;
wire [`DWIDTH-1:0] matrixC15_14_added;
wire [`DWIDTH-1:0] matrixC15_15_added;


reg [`DWIDTH-1:0] matrixC0_0_accum;
reg [`DWIDTH-1:0] matrixC0_1_accum;
reg [`DWIDTH-1:0] matrixC0_2_accum;
reg [`DWIDTH-1:0] matrixC0_3_accum;
reg [`DWIDTH-1:0] matrixC0_4_accum;
reg [`DWIDTH-1:0] matrixC0_5_accum;
reg [`DWIDTH-1:0] matrixC0_6_accum;
reg [`DWIDTH-1:0] matrixC0_7_accum;
reg [`DWIDTH-1:0] matrixC0_8_accum;
reg [`DWIDTH-1:0] matrixC0_9_accum;
reg [`DWIDTH-1:0] matrixC0_10_accum;
reg [`DWIDTH-1:0] matrixC0_11_accum;
reg [`DWIDTH-1:0] matrixC0_12_accum;
reg [`DWIDTH-1:0] matrixC0_13_accum;
reg [`DWIDTH-1:0] matrixC0_14_accum;
reg [`DWIDTH-1:0] matrixC0_15_accum;
reg [`DWIDTH-1:0] matrixC1_0_accum;
reg [`DWIDTH-1:0] matrixC1_1_accum;
reg [`DWIDTH-1:0] matrixC1_2_accum;
reg [`DWIDTH-1:0] matrixC1_3_accum;
reg [`DWIDTH-1:0] matrixC1_4_accum;
reg [`DWIDTH-1:0] matrixC1_5_accum;
reg [`DWIDTH-1:0] matrixC1_6_accum;
reg [`DWIDTH-1:0] matrixC1_7_accum;
reg [`DWIDTH-1:0] matrixC1_8_accum;
reg [`DWIDTH-1:0] matrixC1_9_accum;
reg [`DWIDTH-1:0] matrixC1_10_accum;
reg [`DWIDTH-1:0] matrixC1_11_accum;
reg [`DWIDTH-1:0] matrixC1_12_accum;
reg [`DWIDTH-1:0] matrixC1_13_accum;
reg [`DWIDTH-1:0] matrixC1_14_accum;
reg [`DWIDTH-1:0] matrixC1_15_accum;
reg [`DWIDTH-1:0] matrixC2_0_accum;
reg [`DWIDTH-1:0] matrixC2_1_accum;
reg [`DWIDTH-1:0] matrixC2_2_accum;
reg [`DWIDTH-1:0] matrixC2_3_accum;
reg [`DWIDTH-1:0] matrixC2_4_accum;
reg [`DWIDTH-1:0] matrixC2_5_accum;
reg [`DWIDTH-1:0] matrixC2_6_accum;
reg [`DWIDTH-1:0] matrixC2_7_accum;
reg [`DWIDTH-1:0] matrixC2_8_accum;
reg [`DWIDTH-1:0] matrixC2_9_accum;
reg [`DWIDTH-1:0] matrixC2_10_accum;
reg [`DWIDTH-1:0] matrixC2_11_accum;
reg [`DWIDTH-1:0] matrixC2_12_accum;
reg [`DWIDTH-1:0] matrixC2_13_accum;
reg [`DWIDTH-1:0] matrixC2_14_accum;
reg [`DWIDTH-1:0] matrixC2_15_accum;
reg [`DWIDTH-1:0] matrixC3_0_accum;
reg [`DWIDTH-1:0] matrixC3_1_accum;
reg [`DWIDTH-1:0] matrixC3_2_accum;
reg [`DWIDTH-1:0] matrixC3_3_accum;
reg [`DWIDTH-1:0] matrixC3_4_accum;
reg [`DWIDTH-1:0] matrixC3_5_accum;
reg [`DWIDTH-1:0] matrixC3_6_accum;
reg [`DWIDTH-1:0] matrixC3_7_accum;
reg [`DWIDTH-1:0] matrixC3_8_accum;
reg [`DWIDTH-1:0] matrixC3_9_accum;
reg [`DWIDTH-1:0] matrixC3_10_accum;
reg [`DWIDTH-1:0] matrixC3_11_accum;
reg [`DWIDTH-1:0] matrixC3_12_accum;
reg [`DWIDTH-1:0] matrixC3_13_accum;
reg [`DWIDTH-1:0] matrixC3_14_accum;
reg [`DWIDTH-1:0] matrixC3_15_accum;
reg [`DWIDTH-1:0] matrixC4_0_accum;
reg [`DWIDTH-1:0] matrixC4_1_accum;
reg [`DWIDTH-1:0] matrixC4_2_accum;
reg [`DWIDTH-1:0] matrixC4_3_accum;
reg [`DWIDTH-1:0] matrixC4_4_accum;
reg [`DWIDTH-1:0] matrixC4_5_accum;
reg [`DWIDTH-1:0] matrixC4_6_accum;
reg [`DWIDTH-1:0] matrixC4_7_accum;
reg [`DWIDTH-1:0] matrixC4_8_accum;
reg [`DWIDTH-1:0] matrixC4_9_accum;
reg [`DWIDTH-1:0] matrixC4_10_accum;
reg [`DWIDTH-1:0] matrixC4_11_accum;
reg [`DWIDTH-1:0] matrixC4_12_accum;
reg [`DWIDTH-1:0] matrixC4_13_accum;
reg [`DWIDTH-1:0] matrixC4_14_accum;
reg [`DWIDTH-1:0] matrixC4_15_accum;
reg [`DWIDTH-1:0] matrixC5_0_accum;
reg [`DWIDTH-1:0] matrixC5_1_accum;
reg [`DWIDTH-1:0] matrixC5_2_accum;
reg [`DWIDTH-1:0] matrixC5_3_accum;
reg [`DWIDTH-1:0] matrixC5_4_accum;
reg [`DWIDTH-1:0] matrixC5_5_accum;
reg [`DWIDTH-1:0] matrixC5_6_accum;
reg [`DWIDTH-1:0] matrixC5_7_accum;
reg [`DWIDTH-1:0] matrixC5_8_accum;
reg [`DWIDTH-1:0] matrixC5_9_accum;
reg [`DWIDTH-1:0] matrixC5_10_accum;
reg [`DWIDTH-1:0] matrixC5_11_accum;
reg [`DWIDTH-1:0] matrixC5_12_accum;
reg [`DWIDTH-1:0] matrixC5_13_accum;
reg [`DWIDTH-1:0] matrixC5_14_accum;
reg [`DWIDTH-1:0] matrixC5_15_accum;
reg [`DWIDTH-1:0] matrixC6_0_accum;
reg [`DWIDTH-1:0] matrixC6_1_accum;
reg [`DWIDTH-1:0] matrixC6_2_accum;
reg [`DWIDTH-1:0] matrixC6_3_accum;
reg [`DWIDTH-1:0] matrixC6_4_accum;
reg [`DWIDTH-1:0] matrixC6_5_accum;
reg [`DWIDTH-1:0] matrixC6_6_accum;
reg [`DWIDTH-1:0] matrixC6_7_accum;
reg [`DWIDTH-1:0] matrixC6_8_accum;
reg [`DWIDTH-1:0] matrixC6_9_accum;
reg [`DWIDTH-1:0] matrixC6_10_accum;
reg [`DWIDTH-1:0] matrixC6_11_accum;
reg [`DWIDTH-1:0] matrixC6_12_accum;
reg [`DWIDTH-1:0] matrixC6_13_accum;
reg [`DWIDTH-1:0] matrixC6_14_accum;
reg [`DWIDTH-1:0] matrixC6_15_accum;
reg [`DWIDTH-1:0] matrixC7_0_accum;
reg [`DWIDTH-1:0] matrixC7_1_accum;
reg [`DWIDTH-1:0] matrixC7_2_accum;
reg [`DWIDTH-1:0] matrixC7_3_accum;
reg [`DWIDTH-1:0] matrixC7_4_accum;
reg [`DWIDTH-1:0] matrixC7_5_accum;
reg [`DWIDTH-1:0] matrixC7_6_accum;
reg [`DWIDTH-1:0] matrixC7_7_accum;
reg [`DWIDTH-1:0] matrixC7_8_accum;
reg [`DWIDTH-1:0] matrixC7_9_accum;
reg [`DWIDTH-1:0] matrixC7_10_accum;
reg [`DWIDTH-1:0] matrixC7_11_accum;
reg [`DWIDTH-1:0] matrixC7_12_accum;
reg [`DWIDTH-1:0] matrixC7_13_accum;
reg [`DWIDTH-1:0] matrixC7_14_accum;
reg [`DWIDTH-1:0] matrixC7_15_accum;
reg [`DWIDTH-1:0] matrixC8_0_accum;
reg [`DWIDTH-1:0] matrixC8_1_accum;
reg [`DWIDTH-1:0] matrixC8_2_accum;
reg [`DWIDTH-1:0] matrixC8_3_accum;
reg [`DWIDTH-1:0] matrixC8_4_accum;
reg [`DWIDTH-1:0] matrixC8_5_accum;
reg [`DWIDTH-1:0] matrixC8_6_accum;
reg [`DWIDTH-1:0] matrixC8_7_accum;
reg [`DWIDTH-1:0] matrixC8_8_accum;
reg [`DWIDTH-1:0] matrixC8_9_accum;
reg [`DWIDTH-1:0] matrixC8_10_accum;
reg [`DWIDTH-1:0] matrixC8_11_accum;
reg [`DWIDTH-1:0] matrixC8_12_accum;
reg [`DWIDTH-1:0] matrixC8_13_accum;
reg [`DWIDTH-1:0] matrixC8_14_accum;
reg [`DWIDTH-1:0] matrixC8_15_accum;
reg [`DWIDTH-1:0] matrixC9_0_accum;
reg [`DWIDTH-1:0] matrixC9_1_accum;
reg [`DWIDTH-1:0] matrixC9_2_accum;
reg [`DWIDTH-1:0] matrixC9_3_accum;
reg [`DWIDTH-1:0] matrixC9_4_accum;
reg [`DWIDTH-1:0] matrixC9_5_accum;
reg [`DWIDTH-1:0] matrixC9_6_accum;
reg [`DWIDTH-1:0] matrixC9_7_accum;
reg [`DWIDTH-1:0] matrixC9_8_accum;
reg [`DWIDTH-1:0] matrixC9_9_accum;
reg [`DWIDTH-1:0] matrixC9_10_accum;
reg [`DWIDTH-1:0] matrixC9_11_accum;
reg [`DWIDTH-1:0] matrixC9_12_accum;
reg [`DWIDTH-1:0] matrixC9_13_accum;
reg [`DWIDTH-1:0] matrixC9_14_accum;
reg [`DWIDTH-1:0] matrixC9_15_accum;
reg [`DWIDTH-1:0] matrixC10_0_accum;
reg [`DWIDTH-1:0] matrixC10_1_accum;
reg [`DWIDTH-1:0] matrixC10_2_accum;
reg [`DWIDTH-1:0] matrixC10_3_accum;
reg [`DWIDTH-1:0] matrixC10_4_accum;
reg [`DWIDTH-1:0] matrixC10_5_accum;
reg [`DWIDTH-1:0] matrixC10_6_accum;
reg [`DWIDTH-1:0] matrixC10_7_accum;
reg [`DWIDTH-1:0] matrixC10_8_accum;
reg [`DWIDTH-1:0] matrixC10_9_accum;
reg [`DWIDTH-1:0] matrixC10_10_accum;
reg [`DWIDTH-1:0] matrixC10_11_accum;
reg [`DWIDTH-1:0] matrixC10_12_accum;
reg [`DWIDTH-1:0] matrixC10_13_accum;
reg [`DWIDTH-1:0] matrixC10_14_accum;
reg [`DWIDTH-1:0] matrixC10_15_accum;
reg [`DWIDTH-1:0] matrixC11_0_accum;
reg [`DWIDTH-1:0] matrixC11_1_accum;
reg [`DWIDTH-1:0] matrixC11_2_accum;
reg [`DWIDTH-1:0] matrixC11_3_accum;
reg [`DWIDTH-1:0] matrixC11_4_accum;
reg [`DWIDTH-1:0] matrixC11_5_accum;
reg [`DWIDTH-1:0] matrixC11_6_accum;
reg [`DWIDTH-1:0] matrixC11_7_accum;
reg [`DWIDTH-1:0] matrixC11_8_accum;
reg [`DWIDTH-1:0] matrixC11_9_accum;
reg [`DWIDTH-1:0] matrixC11_10_accum;
reg [`DWIDTH-1:0] matrixC11_11_accum;
reg [`DWIDTH-1:0] matrixC11_12_accum;
reg [`DWIDTH-1:0] matrixC11_13_accum;
reg [`DWIDTH-1:0] matrixC11_14_accum;
reg [`DWIDTH-1:0] matrixC11_15_accum;
reg [`DWIDTH-1:0] matrixC12_0_accum;
reg [`DWIDTH-1:0] matrixC12_1_accum;
reg [`DWIDTH-1:0] matrixC12_2_accum;
reg [`DWIDTH-1:0] matrixC12_3_accum;
reg [`DWIDTH-1:0] matrixC12_4_accum;
reg [`DWIDTH-1:0] matrixC12_5_accum;
reg [`DWIDTH-1:0] matrixC12_6_accum;
reg [`DWIDTH-1:0] matrixC12_7_accum;
reg [`DWIDTH-1:0] matrixC12_8_accum;
reg [`DWIDTH-1:0] matrixC12_9_accum;
reg [`DWIDTH-1:0] matrixC12_10_accum;
reg [`DWIDTH-1:0] matrixC12_11_accum;
reg [`DWIDTH-1:0] matrixC12_12_accum;
reg [`DWIDTH-1:0] matrixC12_13_accum;
reg [`DWIDTH-1:0] matrixC12_14_accum;
reg [`DWIDTH-1:0] matrixC12_15_accum;
reg [`DWIDTH-1:0] matrixC13_0_accum;
reg [`DWIDTH-1:0] matrixC13_1_accum;
reg [`DWIDTH-1:0] matrixC13_2_accum;
reg [`DWIDTH-1:0] matrixC13_3_accum;
reg [`DWIDTH-1:0] matrixC13_4_accum;
reg [`DWIDTH-1:0] matrixC13_5_accum;
reg [`DWIDTH-1:0] matrixC13_6_accum;
reg [`DWIDTH-1:0] matrixC13_7_accum;
reg [`DWIDTH-1:0] matrixC13_8_accum;
reg [`DWIDTH-1:0] matrixC13_9_accum;
reg [`DWIDTH-1:0] matrixC13_10_accum;
reg [`DWIDTH-1:0] matrixC13_11_accum;
reg [`DWIDTH-1:0] matrixC13_12_accum;
reg [`DWIDTH-1:0] matrixC13_13_accum;
reg [`DWIDTH-1:0] matrixC13_14_accum;
reg [`DWIDTH-1:0] matrixC13_15_accum;
reg [`DWIDTH-1:0] matrixC14_0_accum;
reg [`DWIDTH-1:0] matrixC14_1_accum;
reg [`DWIDTH-1:0] matrixC14_2_accum;
reg [`DWIDTH-1:0] matrixC14_3_accum;
reg [`DWIDTH-1:0] matrixC14_4_accum;
reg [`DWIDTH-1:0] matrixC14_5_accum;
reg [`DWIDTH-1:0] matrixC14_6_accum;
reg [`DWIDTH-1:0] matrixC14_7_accum;
reg [`DWIDTH-1:0] matrixC14_8_accum;
reg [`DWIDTH-1:0] matrixC14_9_accum;
reg [`DWIDTH-1:0] matrixC14_10_accum;
reg [`DWIDTH-1:0] matrixC14_11_accum;
reg [`DWIDTH-1:0] matrixC14_12_accum;
reg [`DWIDTH-1:0] matrixC14_13_accum;
reg [`DWIDTH-1:0] matrixC14_14_accum;
reg [`DWIDTH-1:0] matrixC14_15_accum;
reg [`DWIDTH-1:0] matrixC15_0_accum;
reg [`DWIDTH-1:0] matrixC15_1_accum;
reg [`DWIDTH-1:0] matrixC15_2_accum;
reg [`DWIDTH-1:0] matrixC15_3_accum;
reg [`DWIDTH-1:0] matrixC15_4_accum;
reg [`DWIDTH-1:0] matrixC15_5_accum;
reg [`DWIDTH-1:0] matrixC15_6_accum;
reg [`DWIDTH-1:0] matrixC15_7_accum;
reg [`DWIDTH-1:0] matrixC15_8_accum;
reg [`DWIDTH-1:0] matrixC15_9_accum;
reg [`DWIDTH-1:0] matrixC15_10_accum;
reg [`DWIDTH-1:0] matrixC15_11_accum;
reg [`DWIDTH-1:0] matrixC15_12_accum;
reg [`DWIDTH-1:0] matrixC15_13_accum;
reg [`DWIDTH-1:0] matrixC15_14_accum;
reg [`DWIDTH-1:0] matrixC15_15_accum;

  reg outputs_saved_to_accum;
  reg outputs_added_to_accum;
  wire reset_accum;
  
  always @(posedge clk) begin
    if (reset || ~(save_output_to_accum || add_accum_to_output) || (reset_accum)) begin
  matrixC0_0_accum <= 0;
matrixC0_1_accum <= 0;
matrixC0_2_accum <= 0;
matrixC0_3_accum <= 0;
matrixC0_4_accum <= 0;
matrixC0_5_accum <= 0;
matrixC0_6_accum <= 0;
matrixC0_7_accum <= 0;
matrixC0_8_accum <= 0;
matrixC0_9_accum <= 0;
matrixC0_10_accum <= 0;
matrixC0_11_accum <= 0;
matrixC0_12_accum <= 0;
matrixC0_13_accum <= 0;
matrixC0_14_accum <= 0;
matrixC0_15_accum <= 0;
matrixC1_0_accum <= 0;
matrixC1_1_accum <= 0;
matrixC1_2_accum <= 0;
matrixC1_3_accum <= 0;
matrixC1_4_accum <= 0;
matrixC1_5_accum <= 0;
matrixC1_6_accum <= 0;
matrixC1_7_accum <= 0;
matrixC1_8_accum <= 0;
matrixC1_9_accum <= 0;
matrixC1_10_accum <= 0;
matrixC1_11_accum <= 0;
matrixC1_12_accum <= 0;
matrixC1_13_accum <= 0;
matrixC1_14_accum <= 0;
matrixC1_15_accum <= 0;
matrixC2_0_accum <= 0;
matrixC2_1_accum <= 0;
matrixC2_2_accum <= 0;
matrixC2_3_accum <= 0;
matrixC2_4_accum <= 0;
matrixC2_5_accum <= 0;
matrixC2_6_accum <= 0;
matrixC2_7_accum <= 0;
matrixC2_8_accum <= 0;
matrixC2_9_accum <= 0;
matrixC2_10_accum <= 0;
matrixC2_11_accum <= 0;
matrixC2_12_accum <= 0;
matrixC2_13_accum <= 0;
matrixC2_14_accum <= 0;
matrixC2_15_accum <= 0;
matrixC3_0_accum <= 0;
matrixC3_1_accum <= 0;
matrixC3_2_accum <= 0;
matrixC3_3_accum <= 0;
matrixC3_4_accum <= 0;
matrixC3_5_accum <= 0;
matrixC3_6_accum <= 0;
matrixC3_7_accum <= 0;
matrixC3_8_accum <= 0;
matrixC3_9_accum <= 0;
matrixC3_10_accum <= 0;
matrixC3_11_accum <= 0;
matrixC3_12_accum <= 0;
matrixC3_13_accum <= 0;
matrixC3_14_accum <= 0;
matrixC3_15_accum <= 0;
matrixC4_0_accum <= 0;
matrixC4_1_accum <= 0;
matrixC4_2_accum <= 0;
matrixC4_3_accum <= 0;
matrixC4_4_accum <= 0;
matrixC4_5_accum <= 0;
matrixC4_6_accum <= 0;
matrixC4_7_accum <= 0;
matrixC4_8_accum <= 0;
matrixC4_9_accum <= 0;
matrixC4_10_accum <= 0;
matrixC4_11_accum <= 0;
matrixC4_12_accum <= 0;
matrixC4_13_accum <= 0;
matrixC4_14_accum <= 0;
matrixC4_15_accum <= 0;
matrixC5_0_accum <= 0;
matrixC5_1_accum <= 0;
matrixC5_2_accum <= 0;
matrixC5_3_accum <= 0;
matrixC5_4_accum <= 0;
matrixC5_5_accum <= 0;
matrixC5_6_accum <= 0;
matrixC5_7_accum <= 0;
matrixC5_8_accum <= 0;
matrixC5_9_accum <= 0;
matrixC5_10_accum <= 0;
matrixC5_11_accum <= 0;
matrixC5_12_accum <= 0;
matrixC5_13_accum <= 0;
matrixC5_14_accum <= 0;
matrixC5_15_accum <= 0;
matrixC6_0_accum <= 0;
matrixC6_1_accum <= 0;
matrixC6_2_accum <= 0;
matrixC6_3_accum <= 0;
matrixC6_4_accum <= 0;
matrixC6_5_accum <= 0;
matrixC6_6_accum <= 0;
matrixC6_7_accum <= 0;
matrixC6_8_accum <= 0;
matrixC6_9_accum <= 0;
matrixC6_10_accum <= 0;
matrixC6_11_accum <= 0;
matrixC6_12_accum <= 0;
matrixC6_13_accum <= 0;
matrixC6_14_accum <= 0;
matrixC6_15_accum <= 0;
matrixC7_0_accum <= 0;
matrixC7_1_accum <= 0;
matrixC7_2_accum <= 0;
matrixC7_3_accum <= 0;
matrixC7_4_accum <= 0;
matrixC7_5_accum <= 0;
matrixC7_6_accum <= 0;
matrixC7_7_accum <= 0;
matrixC7_8_accum <= 0;
matrixC7_9_accum <= 0;
matrixC7_10_accum <= 0;
matrixC7_11_accum <= 0;
matrixC7_12_accum <= 0;
matrixC7_13_accum <= 0;
matrixC7_14_accum <= 0;
matrixC7_15_accum <= 0;
matrixC8_0_accum <= 0;
matrixC8_1_accum <= 0;
matrixC8_2_accum <= 0;
matrixC8_3_accum <= 0;
matrixC8_4_accum <= 0;
matrixC8_5_accum <= 0;
matrixC8_6_accum <= 0;
matrixC8_7_accum <= 0;
matrixC8_8_accum <= 0;
matrixC8_9_accum <= 0;
matrixC8_10_accum <= 0;
matrixC8_11_accum <= 0;
matrixC8_12_accum <= 0;
matrixC8_13_accum <= 0;
matrixC8_14_accum <= 0;
matrixC8_15_accum <= 0;
matrixC9_0_accum <= 0;
matrixC9_1_accum <= 0;
matrixC9_2_accum <= 0;
matrixC9_3_accum <= 0;
matrixC9_4_accum <= 0;
matrixC9_5_accum <= 0;
matrixC9_6_accum <= 0;
matrixC9_7_accum <= 0;
matrixC9_8_accum <= 0;
matrixC9_9_accum <= 0;
matrixC9_10_accum <= 0;
matrixC9_11_accum <= 0;
matrixC9_12_accum <= 0;
matrixC9_13_accum <= 0;
matrixC9_14_accum <= 0;
matrixC9_15_accum <= 0;
matrixC10_0_accum <= 0;
matrixC10_1_accum <= 0;
matrixC10_2_accum <= 0;
matrixC10_3_accum <= 0;
matrixC10_4_accum <= 0;
matrixC10_5_accum <= 0;
matrixC10_6_accum <= 0;
matrixC10_7_accum <= 0;
matrixC10_8_accum <= 0;
matrixC10_9_accum <= 0;
matrixC10_10_accum <= 0;
matrixC10_11_accum <= 0;
matrixC10_12_accum <= 0;
matrixC10_13_accum <= 0;
matrixC10_14_accum <= 0;
matrixC10_15_accum <= 0;
matrixC11_0_accum <= 0;
matrixC11_1_accum <= 0;
matrixC11_2_accum <= 0;
matrixC11_3_accum <= 0;
matrixC11_4_accum <= 0;
matrixC11_5_accum <= 0;
matrixC11_6_accum <= 0;
matrixC11_7_accum <= 0;
matrixC11_8_accum <= 0;
matrixC11_9_accum <= 0;
matrixC11_10_accum <= 0;
matrixC11_11_accum <= 0;
matrixC11_12_accum <= 0;
matrixC11_13_accum <= 0;
matrixC11_14_accum <= 0;
matrixC11_15_accum <= 0;
matrixC12_0_accum <= 0;
matrixC12_1_accum <= 0;
matrixC12_2_accum <= 0;
matrixC12_3_accum <= 0;
matrixC12_4_accum <= 0;
matrixC12_5_accum <= 0;
matrixC12_6_accum <= 0;
matrixC12_7_accum <= 0;
matrixC12_8_accum <= 0;
matrixC12_9_accum <= 0;
matrixC12_10_accum <= 0;
matrixC12_11_accum <= 0;
matrixC12_12_accum <= 0;
matrixC12_13_accum <= 0;
matrixC12_14_accum <= 0;
matrixC12_15_accum <= 0;
matrixC13_0_accum <= 0;
matrixC13_1_accum <= 0;
matrixC13_2_accum <= 0;
matrixC13_3_accum <= 0;
matrixC13_4_accum <= 0;
matrixC13_5_accum <= 0;
matrixC13_6_accum <= 0;
matrixC13_7_accum <= 0;
matrixC13_8_accum <= 0;
matrixC13_9_accum <= 0;
matrixC13_10_accum <= 0;
matrixC13_11_accum <= 0;
matrixC13_12_accum <= 0;
matrixC13_13_accum <= 0;
matrixC13_14_accum <= 0;
matrixC13_15_accum <= 0;
matrixC14_0_accum <= 0;
matrixC14_1_accum <= 0;
matrixC14_2_accum <= 0;
matrixC14_3_accum <= 0;
matrixC14_4_accum <= 0;
matrixC14_5_accum <= 0;
matrixC14_6_accum <= 0;
matrixC14_7_accum <= 0;
matrixC14_8_accum <= 0;
matrixC14_9_accum <= 0;
matrixC14_10_accum <= 0;
matrixC14_11_accum <= 0;
matrixC14_12_accum <= 0;
matrixC14_13_accum <= 0;
matrixC14_14_accum <= 0;
matrixC14_15_accum <= 0;
matrixC15_0_accum <= 0;
matrixC15_1_accum <= 0;
matrixC15_2_accum <= 0;
matrixC15_3_accum <= 0;
matrixC15_4_accum <= 0;
matrixC15_5_accum <= 0;
matrixC15_6_accum <= 0;
matrixC15_7_accum <= 0;
matrixC15_8_accum <= 0;
matrixC15_9_accum <= 0;
matrixC15_10_accum <= 0;
matrixC15_11_accum <= 0;
matrixC15_12_accum <= 0;
matrixC15_13_accum <= 0;
matrixC15_14_accum <= 0;
matrixC15_15_accum <= 0;
 outputs_saved_to_accum <= 0;
      outputs_added_to_accum <= 0;
  
      cur_c_saved <= 0;
      cur_r_saved <= 0;
      cur_s_saved <= 0;
    
    end
    else if (row_latch_en && save_output_to_accum && add_accum_to_output) begin
  	matrixC0_0_accum <= matrixC0_0_added;
	matrixC0_1_accum <= matrixC0_1_added;
	matrixC0_2_accum <= matrixC0_2_added;
	matrixC0_3_accum <= matrixC0_3_added;
	matrixC0_4_accum <= matrixC0_4_added;
	matrixC0_5_accum <= matrixC0_5_added;
	matrixC0_6_accum <= matrixC0_6_added;
	matrixC0_7_accum <= matrixC0_7_added;
	matrixC0_8_accum <= matrixC0_8_added;
	matrixC0_9_accum <= matrixC0_9_added;
	matrixC0_10_accum <= matrixC0_10_added;
	matrixC0_11_accum <= matrixC0_11_added;
	matrixC0_12_accum <= matrixC0_12_added;
	matrixC0_13_accum <= matrixC0_13_added;
	matrixC0_14_accum <= matrixC0_14_added;
	matrixC0_15_accum <= matrixC0_15_added;
	matrixC1_0_accum <= matrixC1_0_added;
	matrixC1_1_accum <= matrixC1_1_added;
	matrixC1_2_accum <= matrixC1_2_added;
	matrixC1_3_accum <= matrixC1_3_added;
	matrixC1_4_accum <= matrixC1_4_added;
	matrixC1_5_accum <= matrixC1_5_added;
	matrixC1_6_accum <= matrixC1_6_added;
	matrixC1_7_accum <= matrixC1_7_added;
	matrixC1_8_accum <= matrixC1_8_added;
	matrixC1_9_accum <= matrixC1_9_added;
	matrixC1_10_accum <= matrixC1_10_added;
	matrixC1_11_accum <= matrixC1_11_added;
	matrixC1_12_accum <= matrixC1_12_added;
	matrixC1_13_accum <= matrixC1_13_added;
	matrixC1_14_accum <= matrixC1_14_added;
	matrixC1_15_accum <= matrixC1_15_added;
	matrixC2_0_accum <= matrixC2_0_added;
	matrixC2_1_accum <= matrixC2_1_added;
	matrixC2_2_accum <= matrixC2_2_added;
	matrixC2_3_accum <= matrixC2_3_added;
	matrixC2_4_accum <= matrixC2_4_added;
	matrixC2_5_accum <= matrixC2_5_added;
	matrixC2_6_accum <= matrixC2_6_added;
	matrixC2_7_accum <= matrixC2_7_added;
	matrixC2_8_accum <= matrixC2_8_added;
	matrixC2_9_accum <= matrixC2_9_added;
	matrixC2_10_accum <= matrixC2_10_added;
	matrixC2_11_accum <= matrixC2_11_added;
	matrixC2_12_accum <= matrixC2_12_added;
	matrixC2_13_accum <= matrixC2_13_added;
	matrixC2_14_accum <= matrixC2_14_added;
	matrixC2_15_accum <= matrixC2_15_added;
	matrixC3_0_accum <= matrixC3_0_added;
	matrixC3_1_accum <= matrixC3_1_added;
	matrixC3_2_accum <= matrixC3_2_added;
	matrixC3_3_accum <= matrixC3_3_added;
	matrixC3_4_accum <= matrixC3_4_added;
	matrixC3_5_accum <= matrixC3_5_added;
	matrixC3_6_accum <= matrixC3_6_added;
	matrixC3_7_accum <= matrixC3_7_added;
	matrixC3_8_accum <= matrixC3_8_added;
	matrixC3_9_accum <= matrixC3_9_added;
	matrixC3_10_accum <= matrixC3_10_added;
	matrixC3_11_accum <= matrixC3_11_added;
	matrixC3_12_accum <= matrixC3_12_added;
	matrixC3_13_accum <= matrixC3_13_added;
	matrixC3_14_accum <= matrixC3_14_added;
	matrixC3_15_accum <= matrixC3_15_added;
	matrixC4_0_accum <= matrixC4_0_added;
	matrixC4_1_accum <= matrixC4_1_added;
	matrixC4_2_accum <= matrixC4_2_added;
	matrixC4_3_accum <= matrixC4_3_added;
	matrixC4_4_accum <= matrixC4_4_added;
	matrixC4_5_accum <= matrixC4_5_added;
	matrixC4_6_accum <= matrixC4_6_added;
	matrixC4_7_accum <= matrixC4_7_added;
	matrixC4_8_accum <= matrixC4_8_added;
	matrixC4_9_accum <= matrixC4_9_added;
	matrixC4_10_accum <= matrixC4_10_added;
	matrixC4_11_accum <= matrixC4_11_added;
	matrixC4_12_accum <= matrixC4_12_added;
	matrixC4_13_accum <= matrixC4_13_added;
	matrixC4_14_accum <= matrixC4_14_added;
	matrixC4_15_accum <= matrixC4_15_added;
	matrixC5_0_accum <= matrixC5_0_added;
	matrixC5_1_accum <= matrixC5_1_added;
	matrixC5_2_accum <= matrixC5_2_added;
	matrixC5_3_accum <= matrixC5_3_added;
	matrixC5_4_accum <= matrixC5_4_added;
	matrixC5_5_accum <= matrixC5_5_added;
	matrixC5_6_accum <= matrixC5_6_added;
	matrixC5_7_accum <= matrixC5_7_added;
	matrixC5_8_accum <= matrixC5_8_added;
	matrixC5_9_accum <= matrixC5_9_added;
	matrixC5_10_accum <= matrixC5_10_added;
	matrixC5_11_accum <= matrixC5_11_added;
	matrixC5_12_accum <= matrixC5_12_added;
	matrixC5_13_accum <= matrixC5_13_added;
	matrixC5_14_accum <= matrixC5_14_added;
	matrixC5_15_accum <= matrixC5_15_added;
	matrixC6_0_accum <= matrixC6_0_added;
	matrixC6_1_accum <= matrixC6_1_added;
	matrixC6_2_accum <= matrixC6_2_added;
	matrixC6_3_accum <= matrixC6_3_added;
	matrixC6_4_accum <= matrixC6_4_added;
	matrixC6_5_accum <= matrixC6_5_added;
	matrixC6_6_accum <= matrixC6_6_added;
	matrixC6_7_accum <= matrixC6_7_added;
	matrixC6_8_accum <= matrixC6_8_added;
	matrixC6_9_accum <= matrixC6_9_added;
	matrixC6_10_accum <= matrixC6_10_added;
	matrixC6_11_accum <= matrixC6_11_added;
	matrixC6_12_accum <= matrixC6_12_added;
	matrixC6_13_accum <= matrixC6_13_added;
	matrixC6_14_accum <= matrixC6_14_added;
	matrixC6_15_accum <= matrixC6_15_added;
	matrixC7_0_accum <= matrixC7_0_added;
	matrixC7_1_accum <= matrixC7_1_added;
	matrixC7_2_accum <= matrixC7_2_added;
	matrixC7_3_accum <= matrixC7_3_added;
	matrixC7_4_accum <= matrixC7_4_added;
	matrixC7_5_accum <= matrixC7_5_added;
	matrixC7_6_accum <= matrixC7_6_added;
	matrixC7_7_accum <= matrixC7_7_added;
	matrixC7_8_accum <= matrixC7_8_added;
	matrixC7_9_accum <= matrixC7_9_added;
	matrixC7_10_accum <= matrixC7_10_added;
	matrixC7_11_accum <= matrixC7_11_added;
	matrixC7_12_accum <= matrixC7_12_added;
	matrixC7_13_accum <= matrixC7_13_added;
	matrixC7_14_accum <= matrixC7_14_added;
	matrixC7_15_accum <= matrixC7_15_added;
	matrixC8_0_accum <= matrixC8_0_added;
	matrixC8_1_accum <= matrixC8_1_added;
	matrixC8_2_accum <= matrixC8_2_added;
	matrixC8_3_accum <= matrixC8_3_added;
	matrixC8_4_accum <= matrixC8_4_added;
	matrixC8_5_accum <= matrixC8_5_added;
	matrixC8_6_accum <= matrixC8_6_added;
	matrixC8_7_accum <= matrixC8_7_added;
	matrixC8_8_accum <= matrixC8_8_added;
	matrixC8_9_accum <= matrixC8_9_added;
	matrixC8_10_accum <= matrixC8_10_added;
	matrixC8_11_accum <= matrixC8_11_added;
	matrixC8_12_accum <= matrixC8_12_added;
	matrixC8_13_accum <= matrixC8_13_added;
	matrixC8_14_accum <= matrixC8_14_added;
	matrixC8_15_accum <= matrixC8_15_added;
	matrixC9_0_accum <= matrixC9_0_added;
	matrixC9_1_accum <= matrixC9_1_added;
	matrixC9_2_accum <= matrixC9_2_added;
	matrixC9_3_accum <= matrixC9_3_added;
	matrixC9_4_accum <= matrixC9_4_added;
	matrixC9_5_accum <= matrixC9_5_added;
	matrixC9_6_accum <= matrixC9_6_added;
	matrixC9_7_accum <= matrixC9_7_added;
	matrixC9_8_accum <= matrixC9_8_added;
	matrixC9_9_accum <= matrixC9_9_added;
	matrixC9_10_accum <= matrixC9_10_added;
	matrixC9_11_accum <= matrixC9_11_added;
	matrixC9_12_accum <= matrixC9_12_added;
	matrixC9_13_accum <= matrixC9_13_added;
	matrixC9_14_accum <= matrixC9_14_added;
	matrixC9_15_accum <= matrixC9_15_added;
	matrixC10_0_accum <= matrixC10_0_added;
	matrixC10_1_accum <= matrixC10_1_added;
	matrixC10_2_accum <= matrixC10_2_added;
	matrixC10_3_accum <= matrixC10_3_added;
	matrixC10_4_accum <= matrixC10_4_added;
	matrixC10_5_accum <= matrixC10_5_added;
	matrixC10_6_accum <= matrixC10_6_added;
	matrixC10_7_accum <= matrixC10_7_added;
	matrixC10_8_accum <= matrixC10_8_added;
	matrixC10_9_accum <= matrixC10_9_added;
	matrixC10_10_accum <= matrixC10_10_added;
	matrixC10_11_accum <= matrixC10_11_added;
	matrixC10_12_accum <= matrixC10_12_added;
	matrixC10_13_accum <= matrixC10_13_added;
	matrixC10_14_accum <= matrixC10_14_added;
	matrixC10_15_accum <= matrixC10_15_added;
	matrixC11_0_accum <= matrixC11_0_added;
	matrixC11_1_accum <= matrixC11_1_added;
	matrixC11_2_accum <= matrixC11_2_added;
	matrixC11_3_accum <= matrixC11_3_added;
	matrixC11_4_accum <= matrixC11_4_added;
	matrixC11_5_accum <= matrixC11_5_added;
	matrixC11_6_accum <= matrixC11_6_added;
	matrixC11_7_accum <= matrixC11_7_added;
	matrixC11_8_accum <= matrixC11_8_added;
	matrixC11_9_accum <= matrixC11_9_added;
	matrixC11_10_accum <= matrixC11_10_added;
	matrixC11_11_accum <= matrixC11_11_added;
	matrixC11_12_accum <= matrixC11_12_added;
	matrixC11_13_accum <= matrixC11_13_added;
	matrixC11_14_accum <= matrixC11_14_added;
	matrixC11_15_accum <= matrixC11_15_added;
	matrixC12_0_accum <= matrixC12_0_added;
	matrixC12_1_accum <= matrixC12_1_added;
	matrixC12_2_accum <= matrixC12_2_added;
	matrixC12_3_accum <= matrixC12_3_added;
	matrixC12_4_accum <= matrixC12_4_added;
	matrixC12_5_accum <= matrixC12_5_added;
	matrixC12_6_accum <= matrixC12_6_added;
	matrixC12_7_accum <= matrixC12_7_added;
	matrixC12_8_accum <= matrixC12_8_added;
	matrixC12_9_accum <= matrixC12_9_added;
	matrixC12_10_accum <= matrixC12_10_added;
	matrixC12_11_accum <= matrixC12_11_added;
	matrixC12_12_accum <= matrixC12_12_added;
	matrixC12_13_accum <= matrixC12_13_added;
	matrixC12_14_accum <= matrixC12_14_added;
	matrixC12_15_accum <= matrixC12_15_added;
	matrixC13_0_accum <= matrixC13_0_added;
	matrixC13_1_accum <= matrixC13_1_added;
	matrixC13_2_accum <= matrixC13_2_added;
	matrixC13_3_accum <= matrixC13_3_added;
	matrixC13_4_accum <= matrixC13_4_added;
	matrixC13_5_accum <= matrixC13_5_added;
	matrixC13_6_accum <= matrixC13_6_added;
	matrixC13_7_accum <= matrixC13_7_added;
	matrixC13_8_accum <= matrixC13_8_added;
	matrixC13_9_accum <= matrixC13_9_added;
	matrixC13_10_accum <= matrixC13_10_added;
	matrixC13_11_accum <= matrixC13_11_added;
	matrixC13_12_accum <= matrixC13_12_added;
	matrixC13_13_accum <= matrixC13_13_added;
	matrixC13_14_accum <= matrixC13_14_added;
	matrixC13_15_accum <= matrixC13_15_added;
	matrixC14_0_accum <= matrixC14_0_added;
	matrixC14_1_accum <= matrixC14_1_added;
	matrixC14_2_accum <= matrixC14_2_added;
	matrixC14_3_accum <= matrixC14_3_added;
	matrixC14_4_accum <= matrixC14_4_added;
	matrixC14_5_accum <= matrixC14_5_added;
	matrixC14_6_accum <= matrixC14_6_added;
	matrixC14_7_accum <= matrixC14_7_added;
	matrixC14_8_accum <= matrixC14_8_added;
	matrixC14_9_accum <= matrixC14_9_added;
	matrixC14_10_accum <= matrixC14_10_added;
	matrixC14_11_accum <= matrixC14_11_added;
	matrixC14_12_accum <= matrixC14_12_added;
	matrixC14_13_accum <= matrixC14_13_added;
	matrixC14_14_accum <= matrixC14_14_added;
	matrixC14_15_accum <= matrixC14_15_added;
	matrixC15_0_accum <= matrixC15_0_added;
	matrixC15_1_accum <= matrixC15_1_added;
	matrixC15_2_accum <= matrixC15_2_added;
	matrixC15_3_accum <= matrixC15_3_added;
	matrixC15_4_accum <= matrixC15_4_added;
	matrixC15_5_accum <= matrixC15_5_added;
	matrixC15_6_accum <= matrixC15_6_added;
	matrixC15_7_accum <= matrixC15_7_added;
	matrixC15_8_accum <= matrixC15_8_added;
	matrixC15_9_accum <= matrixC15_9_added;
	matrixC15_10_accum <= matrixC15_10_added;
	matrixC15_11_accum <= matrixC15_11_added;
	matrixC15_12_accum <= matrixC15_12_added;
	matrixC15_13_accum <= matrixC15_13_added;
	matrixC15_14_accum <= matrixC15_14_added;
	matrixC15_15_accum <= matrixC15_15_added;

      outputs_saved_to_accum <= 1;
      outputs_added_to_accum <= 1;
  
      cur_c_saved <= c;
      cur_r_saved <= r;
      cur_s_saved <= s;
    
    end
    else if (row_latch_en && save_output_to_accum) begin
  	matrixC0_0_accum <= matrixC0_0;
	matrixC0_1_accum <= matrixC0_1;
	matrixC0_2_accum <= matrixC0_2;
	matrixC0_3_accum <= matrixC0_3;
	matrixC0_4_accum <= matrixC0_4;
	matrixC0_5_accum <= matrixC0_5;
	matrixC0_6_accum <= matrixC0_6;
	matrixC0_7_accum <= matrixC0_7;
	matrixC0_8_accum <= matrixC0_8;
	matrixC0_9_accum <= matrixC0_9;
	matrixC0_10_accum <= matrixC0_10;
	matrixC0_11_accum <= matrixC0_11;
	matrixC0_12_accum <= matrixC0_12;
	matrixC0_13_accum <= matrixC0_13;
	matrixC0_14_accum <= matrixC0_14;
	matrixC0_15_accum <= matrixC0_15;
	matrixC1_0_accum <= matrixC1_0;
	matrixC1_1_accum <= matrixC1_1;
	matrixC1_2_accum <= matrixC1_2;
	matrixC1_3_accum <= matrixC1_3;
	matrixC1_4_accum <= matrixC1_4;
	matrixC1_5_accum <= matrixC1_5;
	matrixC1_6_accum <= matrixC1_6;
	matrixC1_7_accum <= matrixC1_7;
	matrixC1_8_accum <= matrixC1_8;
	matrixC1_9_accum <= matrixC1_9;
	matrixC1_10_accum <= matrixC1_10;
	matrixC1_11_accum <= matrixC1_11;
	matrixC1_12_accum <= matrixC1_12;
	matrixC1_13_accum <= matrixC1_13;
	matrixC1_14_accum <= matrixC1_14;
	matrixC1_15_accum <= matrixC1_15;
	matrixC2_0_accum <= matrixC2_0;
	matrixC2_1_accum <= matrixC2_1;
	matrixC2_2_accum <= matrixC2_2;
	matrixC2_3_accum <= matrixC2_3;
	matrixC2_4_accum <= matrixC2_4;
	matrixC2_5_accum <= matrixC2_5;
	matrixC2_6_accum <= matrixC2_6;
	matrixC2_7_accum <= matrixC2_7;
	matrixC2_8_accum <= matrixC2_8;
	matrixC2_9_accum <= matrixC2_9;
	matrixC2_10_accum <= matrixC2_10;
	matrixC2_11_accum <= matrixC2_11;
	matrixC2_12_accum <= matrixC2_12;
	matrixC2_13_accum <= matrixC2_13;
	matrixC2_14_accum <= matrixC2_14;
	matrixC2_15_accum <= matrixC2_15;
	matrixC3_0_accum <= matrixC3_0;
	matrixC3_1_accum <= matrixC3_1;
	matrixC3_2_accum <= matrixC3_2;
	matrixC3_3_accum <= matrixC3_3;
	matrixC3_4_accum <= matrixC3_4;
	matrixC3_5_accum <= matrixC3_5;
	matrixC3_6_accum <= matrixC3_6;
	matrixC3_7_accum <= matrixC3_7;
	matrixC3_8_accum <= matrixC3_8;
	matrixC3_9_accum <= matrixC3_9;
	matrixC3_10_accum <= matrixC3_10;
	matrixC3_11_accum <= matrixC3_11;
	matrixC3_12_accum <= matrixC3_12;
	matrixC3_13_accum <= matrixC3_13;
	matrixC3_14_accum <= matrixC3_14;
	matrixC3_15_accum <= matrixC3_15;
	matrixC4_0_accum <= matrixC4_0;
	matrixC4_1_accum <= matrixC4_1;
	matrixC4_2_accum <= matrixC4_2;
	matrixC4_3_accum <= matrixC4_3;
	matrixC4_4_accum <= matrixC4_4;
	matrixC4_5_accum <= matrixC4_5;
	matrixC4_6_accum <= matrixC4_6;
	matrixC4_7_accum <= matrixC4_7;
	matrixC4_8_accum <= matrixC4_8;
	matrixC4_9_accum <= matrixC4_9;
	matrixC4_10_accum <= matrixC4_10;
	matrixC4_11_accum <= matrixC4_11;
	matrixC4_12_accum <= matrixC4_12;
	matrixC4_13_accum <= matrixC4_13;
	matrixC4_14_accum <= matrixC4_14;
	matrixC4_15_accum <= matrixC4_15;
	matrixC5_0_accum <= matrixC5_0;
	matrixC5_1_accum <= matrixC5_1;
	matrixC5_2_accum <= matrixC5_2;
	matrixC5_3_accum <= matrixC5_3;
	matrixC5_4_accum <= matrixC5_4;
	matrixC5_5_accum <= matrixC5_5;
	matrixC5_6_accum <= matrixC5_6;
	matrixC5_7_accum <= matrixC5_7;
	matrixC5_8_accum <= matrixC5_8;
	matrixC5_9_accum <= matrixC5_9;
	matrixC5_10_accum <= matrixC5_10;
	matrixC5_11_accum <= matrixC5_11;
	matrixC5_12_accum <= matrixC5_12;
	matrixC5_13_accum <= matrixC5_13;
	matrixC5_14_accum <= matrixC5_14;
	matrixC5_15_accum <= matrixC5_15;
	matrixC6_0_accum <= matrixC6_0;
	matrixC6_1_accum <= matrixC6_1;
	matrixC6_2_accum <= matrixC6_2;
	matrixC6_3_accum <= matrixC6_3;
	matrixC6_4_accum <= matrixC6_4;
	matrixC6_5_accum <= matrixC6_5;
	matrixC6_6_accum <= matrixC6_6;
	matrixC6_7_accum <= matrixC6_7;
	matrixC6_8_accum <= matrixC6_8;
	matrixC6_9_accum <= matrixC6_9;
	matrixC6_10_accum <= matrixC6_10;
	matrixC6_11_accum <= matrixC6_11;
	matrixC6_12_accum <= matrixC6_12;
	matrixC6_13_accum <= matrixC6_13;
	matrixC6_14_accum <= matrixC6_14;
	matrixC6_15_accum <= matrixC6_15;
	matrixC7_0_accum <= matrixC7_0;
	matrixC7_1_accum <= matrixC7_1;
	matrixC7_2_accum <= matrixC7_2;
	matrixC7_3_accum <= matrixC7_3;
	matrixC7_4_accum <= matrixC7_4;
	matrixC7_5_accum <= matrixC7_5;
	matrixC7_6_accum <= matrixC7_6;
	matrixC7_7_accum <= matrixC7_7;
	matrixC7_8_accum <= matrixC7_8;
	matrixC7_9_accum <= matrixC7_9;
	matrixC7_10_accum <= matrixC7_10;
	matrixC7_11_accum <= matrixC7_11;
	matrixC7_12_accum <= matrixC7_12;
	matrixC7_13_accum <= matrixC7_13;
	matrixC7_14_accum <= matrixC7_14;
	matrixC7_15_accum <= matrixC7_15;
	matrixC8_0_accum <= matrixC8_0;
	matrixC8_1_accum <= matrixC8_1;
	matrixC8_2_accum <= matrixC8_2;
	matrixC8_3_accum <= matrixC8_3;
	matrixC8_4_accum <= matrixC8_4;
	matrixC8_5_accum <= matrixC8_5;
	matrixC8_6_accum <= matrixC8_6;
	matrixC8_7_accum <= matrixC8_7;
	matrixC8_8_accum <= matrixC8_8;
	matrixC8_9_accum <= matrixC8_9;
	matrixC8_10_accum <= matrixC8_10;
	matrixC8_11_accum <= matrixC8_11;
	matrixC8_12_accum <= matrixC8_12;
	matrixC8_13_accum <= matrixC8_13;
	matrixC8_14_accum <= matrixC8_14;
	matrixC8_15_accum <= matrixC8_15;
	matrixC9_0_accum <= matrixC9_0;
	matrixC9_1_accum <= matrixC9_1;
	matrixC9_2_accum <= matrixC9_2;
	matrixC9_3_accum <= matrixC9_3;
	matrixC9_4_accum <= matrixC9_4;
	matrixC9_5_accum <= matrixC9_5;
	matrixC9_6_accum <= matrixC9_6;
	matrixC9_7_accum <= matrixC9_7;
	matrixC9_8_accum <= matrixC9_8;
	matrixC9_9_accum <= matrixC9_9;
	matrixC9_10_accum <= matrixC9_10;
	matrixC9_11_accum <= matrixC9_11;
	matrixC9_12_accum <= matrixC9_12;
	matrixC9_13_accum <= matrixC9_13;
	matrixC9_14_accum <= matrixC9_14;
	matrixC9_15_accum <= matrixC9_15;
	matrixC10_0_accum <= matrixC10_0;
	matrixC10_1_accum <= matrixC10_1;
	matrixC10_2_accum <= matrixC10_2;
	matrixC10_3_accum <= matrixC10_3;
	matrixC10_4_accum <= matrixC10_4;
	matrixC10_5_accum <= matrixC10_5;
	matrixC10_6_accum <= matrixC10_6;
	matrixC10_7_accum <= matrixC10_7;
	matrixC10_8_accum <= matrixC10_8;
	matrixC10_9_accum <= matrixC10_9;
	matrixC10_10_accum <= matrixC10_10;
	matrixC10_11_accum <= matrixC10_11;
	matrixC10_12_accum <= matrixC10_12;
	matrixC10_13_accum <= matrixC10_13;
	matrixC10_14_accum <= matrixC10_14;
	matrixC10_15_accum <= matrixC10_15;
	matrixC11_0_accum <= matrixC11_0;
	matrixC11_1_accum <= matrixC11_1;
	matrixC11_2_accum <= matrixC11_2;
	matrixC11_3_accum <= matrixC11_3;
	matrixC11_4_accum <= matrixC11_4;
	matrixC11_5_accum <= matrixC11_5;
	matrixC11_6_accum <= matrixC11_6;
	matrixC11_7_accum <= matrixC11_7;
	matrixC11_8_accum <= matrixC11_8;
	matrixC11_9_accum <= matrixC11_9;
	matrixC11_10_accum <= matrixC11_10;
	matrixC11_11_accum <= matrixC11_11;
	matrixC11_12_accum <= matrixC11_12;
	matrixC11_13_accum <= matrixC11_13;
	matrixC11_14_accum <= matrixC11_14;
	matrixC11_15_accum <= matrixC11_15;
	matrixC12_0_accum <= matrixC12_0;
	matrixC12_1_accum <= matrixC12_1;
	matrixC12_2_accum <= matrixC12_2;
	matrixC12_3_accum <= matrixC12_3;
	matrixC12_4_accum <= matrixC12_4;
	matrixC12_5_accum <= matrixC12_5;
	matrixC12_6_accum <= matrixC12_6;
	matrixC12_7_accum <= matrixC12_7;
	matrixC12_8_accum <= matrixC12_8;
	matrixC12_9_accum <= matrixC12_9;
	matrixC12_10_accum <= matrixC12_10;
	matrixC12_11_accum <= matrixC12_11;
	matrixC12_12_accum <= matrixC12_12;
	matrixC12_13_accum <= matrixC12_13;
	matrixC12_14_accum <= matrixC12_14;
	matrixC12_15_accum <= matrixC12_15;
	matrixC13_0_accum <= matrixC13_0;
	matrixC13_1_accum <= matrixC13_1;
	matrixC13_2_accum <= matrixC13_2;
	matrixC13_3_accum <= matrixC13_3;
	matrixC13_4_accum <= matrixC13_4;
	matrixC13_5_accum <= matrixC13_5;
	matrixC13_6_accum <= matrixC13_6;
	matrixC13_7_accum <= matrixC13_7;
	matrixC13_8_accum <= matrixC13_8;
	matrixC13_9_accum <= matrixC13_9;
	matrixC13_10_accum <= matrixC13_10;
	matrixC13_11_accum <= matrixC13_11;
	matrixC13_12_accum <= matrixC13_12;
	matrixC13_13_accum <= matrixC13_13;
	matrixC13_14_accum <= matrixC13_14;
	matrixC13_15_accum <= matrixC13_15;
	matrixC14_0_accum <= matrixC14_0;
	matrixC14_1_accum <= matrixC14_1;
	matrixC14_2_accum <= matrixC14_2;
	matrixC14_3_accum <= matrixC14_3;
	matrixC14_4_accum <= matrixC14_4;
	matrixC14_5_accum <= matrixC14_5;
	matrixC14_6_accum <= matrixC14_6;
	matrixC14_7_accum <= matrixC14_7;
	matrixC14_8_accum <= matrixC14_8;
	matrixC14_9_accum <= matrixC14_9;
	matrixC14_10_accum <= matrixC14_10;
	matrixC14_11_accum <= matrixC14_11;
	matrixC14_12_accum <= matrixC14_12;
	matrixC14_13_accum <= matrixC14_13;
	matrixC14_14_accum <= matrixC14_14;
	matrixC14_15_accum <= matrixC14_15;
	matrixC15_0_accum <= matrixC15_0;
	matrixC15_1_accum <= matrixC15_1;
	matrixC15_2_accum <= matrixC15_2;
	matrixC15_3_accum <= matrixC15_3;
	matrixC15_4_accum <= matrixC15_4;
	matrixC15_5_accum <= matrixC15_5;
	matrixC15_6_accum <= matrixC15_6;
	matrixC15_7_accum <= matrixC15_7;
	matrixC15_8_accum <= matrixC15_8;
	matrixC15_9_accum <= matrixC15_9;
	matrixC15_10_accum <= matrixC15_10;
	matrixC15_11_accum <= matrixC15_11;
	matrixC15_12_accum <= matrixC15_12;
	matrixC15_13_accum <= matrixC15_13;
	matrixC15_14_accum <= matrixC15_14;
	matrixC15_15_accum <= matrixC15_15;

      outputs_saved_to_accum <= 1;
  
      cur_c_saved <= c;
      cur_r_saved <= r;
      cur_s_saved <= s;
    
    end
    else if (row_latch_en && add_accum_to_output) begin
      outputs_added_to_accum <= 1;
    end
  end
  assign matrixC0_0_added = (add_accum_to_output) ? (matrixC0_0 + matrixC0_0_accum) : matrixC0_0;
assign matrixC0_1_added = (add_accum_to_output) ? (matrixC0_1 + matrixC0_1_accum) : matrixC0_1;
assign matrixC0_2_added = (add_accum_to_output) ? (matrixC0_2 + matrixC0_2_accum) : matrixC0_2;
assign matrixC0_3_added = (add_accum_to_output) ? (matrixC0_3 + matrixC0_3_accum) : matrixC0_3;
assign matrixC0_4_added = (add_accum_to_output) ? (matrixC0_4 + matrixC0_4_accum) : matrixC0_4;
assign matrixC0_5_added = (add_accum_to_output) ? (matrixC0_5 + matrixC0_5_accum) : matrixC0_5;
assign matrixC0_6_added = (add_accum_to_output) ? (matrixC0_6 + matrixC0_6_accum) : matrixC0_6;
assign matrixC0_7_added = (add_accum_to_output) ? (matrixC0_7 + matrixC0_7_accum) : matrixC0_7;
assign matrixC0_8_added = (add_accum_to_output) ? (matrixC0_8 + matrixC0_8_accum) : matrixC0_8;
assign matrixC0_9_added = (add_accum_to_output) ? (matrixC0_9 + matrixC0_9_accum) : matrixC0_9;
assign matrixC0_10_added = (add_accum_to_output) ? (matrixC0_10 + matrixC0_10_accum) : matrixC0_10;
assign matrixC0_11_added = (add_accum_to_output) ? (matrixC0_11 + matrixC0_11_accum) : matrixC0_11;
assign matrixC0_12_added = (add_accum_to_output) ? (matrixC0_12 + matrixC0_12_accum) : matrixC0_12;
assign matrixC0_13_added = (add_accum_to_output) ? (matrixC0_13 + matrixC0_13_accum) : matrixC0_13;
assign matrixC0_14_added = (add_accum_to_output) ? (matrixC0_14 + matrixC0_14_accum) : matrixC0_14;
assign matrixC0_15_added = (add_accum_to_output) ? (matrixC0_15 + matrixC0_15_accum) : matrixC0_15;
assign matrixC1_0_added = (add_accum_to_output) ? (matrixC1_0 + matrixC1_0_accum) : matrixC1_0;
assign matrixC1_1_added = (add_accum_to_output) ? (matrixC1_1 + matrixC1_1_accum) : matrixC1_1;
assign matrixC1_2_added = (add_accum_to_output) ? (matrixC1_2 + matrixC1_2_accum) : matrixC1_2;
assign matrixC1_3_added = (add_accum_to_output) ? (matrixC1_3 + matrixC1_3_accum) : matrixC1_3;
assign matrixC1_4_added = (add_accum_to_output) ? (matrixC1_4 + matrixC1_4_accum) : matrixC1_4;
assign matrixC1_5_added = (add_accum_to_output) ? (matrixC1_5 + matrixC1_5_accum) : matrixC1_5;
assign matrixC1_6_added = (add_accum_to_output) ? (matrixC1_6 + matrixC1_6_accum) : matrixC1_6;
assign matrixC1_7_added = (add_accum_to_output) ? (matrixC1_7 + matrixC1_7_accum) : matrixC1_7;
assign matrixC1_8_added = (add_accum_to_output) ? (matrixC1_8 + matrixC1_8_accum) : matrixC1_8;
assign matrixC1_9_added = (add_accum_to_output) ? (matrixC1_9 + matrixC1_9_accum) : matrixC1_9;
assign matrixC1_10_added = (add_accum_to_output) ? (matrixC1_10 + matrixC1_10_accum) : matrixC1_10;
assign matrixC1_11_added = (add_accum_to_output) ? (matrixC1_11 + matrixC1_11_accum) : matrixC1_11;
assign matrixC1_12_added = (add_accum_to_output) ? (matrixC1_12 + matrixC1_12_accum) : matrixC1_12;
assign matrixC1_13_added = (add_accum_to_output) ? (matrixC1_13 + matrixC1_13_accum) : matrixC1_13;
assign matrixC1_14_added = (add_accum_to_output) ? (matrixC1_14 + matrixC1_14_accum) : matrixC1_14;
assign matrixC1_15_added = (add_accum_to_output) ? (matrixC1_15 + matrixC1_15_accum) : matrixC1_15;
assign matrixC2_0_added = (add_accum_to_output) ? (matrixC2_0 + matrixC2_0_accum) : matrixC2_0;
assign matrixC2_1_added = (add_accum_to_output) ? (matrixC2_1 + matrixC2_1_accum) : matrixC2_1;
assign matrixC2_2_added = (add_accum_to_output) ? (matrixC2_2 + matrixC2_2_accum) : matrixC2_2;
assign matrixC2_3_added = (add_accum_to_output) ? (matrixC2_3 + matrixC2_3_accum) : matrixC2_3;
assign matrixC2_4_added = (add_accum_to_output) ? (matrixC2_4 + matrixC2_4_accum) : matrixC2_4;
assign matrixC2_5_added = (add_accum_to_output) ? (matrixC2_5 + matrixC2_5_accum) : matrixC2_5;
assign matrixC2_6_added = (add_accum_to_output) ? (matrixC2_6 + matrixC2_6_accum) : matrixC2_6;
assign matrixC2_7_added = (add_accum_to_output) ? (matrixC2_7 + matrixC2_7_accum) : matrixC2_7;
assign matrixC2_8_added = (add_accum_to_output) ? (matrixC2_8 + matrixC2_8_accum) : matrixC2_8;
assign matrixC2_9_added = (add_accum_to_output) ? (matrixC2_9 + matrixC2_9_accum) : matrixC2_9;
assign matrixC2_10_added = (add_accum_to_output) ? (matrixC2_10 + matrixC2_10_accum) : matrixC2_10;
assign matrixC2_11_added = (add_accum_to_output) ? (matrixC2_11 + matrixC2_11_accum) : matrixC2_11;
assign matrixC2_12_added = (add_accum_to_output) ? (matrixC2_12 + matrixC2_12_accum) : matrixC2_12;
assign matrixC2_13_added = (add_accum_to_output) ? (matrixC2_13 + matrixC2_13_accum) : matrixC2_13;
assign matrixC2_14_added = (add_accum_to_output) ? (matrixC2_14 + matrixC2_14_accum) : matrixC2_14;
assign matrixC2_15_added = (add_accum_to_output) ? (matrixC2_15 + matrixC2_15_accum) : matrixC2_15;
assign matrixC3_0_added = (add_accum_to_output) ? (matrixC3_0 + matrixC3_0_accum) : matrixC3_0;
assign matrixC3_1_added = (add_accum_to_output) ? (matrixC3_1 + matrixC3_1_accum) : matrixC3_1;
assign matrixC3_2_added = (add_accum_to_output) ? (matrixC3_2 + matrixC3_2_accum) : matrixC3_2;
assign matrixC3_3_added = (add_accum_to_output) ? (matrixC3_3 + matrixC3_3_accum) : matrixC3_3;
assign matrixC3_4_added = (add_accum_to_output) ? (matrixC3_4 + matrixC3_4_accum) : matrixC3_4;
assign matrixC3_5_added = (add_accum_to_output) ? (matrixC3_5 + matrixC3_5_accum) : matrixC3_5;
assign matrixC3_6_added = (add_accum_to_output) ? (matrixC3_6 + matrixC3_6_accum) : matrixC3_6;
assign matrixC3_7_added = (add_accum_to_output) ? (matrixC3_7 + matrixC3_7_accum) : matrixC3_7;
assign matrixC3_8_added = (add_accum_to_output) ? (matrixC3_8 + matrixC3_8_accum) : matrixC3_8;
assign matrixC3_9_added = (add_accum_to_output) ? (matrixC3_9 + matrixC3_9_accum) : matrixC3_9;
assign matrixC3_10_added = (add_accum_to_output) ? (matrixC3_10 + matrixC3_10_accum) : matrixC3_10;
assign matrixC3_11_added = (add_accum_to_output) ? (matrixC3_11 + matrixC3_11_accum) : matrixC3_11;
assign matrixC3_12_added = (add_accum_to_output) ? (matrixC3_12 + matrixC3_12_accum) : matrixC3_12;
assign matrixC3_13_added = (add_accum_to_output) ? (matrixC3_13 + matrixC3_13_accum) : matrixC3_13;
assign matrixC3_14_added = (add_accum_to_output) ? (matrixC3_14 + matrixC3_14_accum) : matrixC3_14;
assign matrixC3_15_added = (add_accum_to_output) ? (matrixC3_15 + matrixC3_15_accum) : matrixC3_15;
assign matrixC4_0_added = (add_accum_to_output) ? (matrixC4_0 + matrixC4_0_accum) : matrixC4_0;
assign matrixC4_1_added = (add_accum_to_output) ? (matrixC4_1 + matrixC4_1_accum) : matrixC4_1;
assign matrixC4_2_added = (add_accum_to_output) ? (matrixC4_2 + matrixC4_2_accum) : matrixC4_2;
assign matrixC4_3_added = (add_accum_to_output) ? (matrixC4_3 + matrixC4_3_accum) : matrixC4_3;
assign matrixC4_4_added = (add_accum_to_output) ? (matrixC4_4 + matrixC4_4_accum) : matrixC4_4;
assign matrixC4_5_added = (add_accum_to_output) ? (matrixC4_5 + matrixC4_5_accum) : matrixC4_5;
assign matrixC4_6_added = (add_accum_to_output) ? (matrixC4_6 + matrixC4_6_accum) : matrixC4_6;
assign matrixC4_7_added = (add_accum_to_output) ? (matrixC4_7 + matrixC4_7_accum) : matrixC4_7;
assign matrixC4_8_added = (add_accum_to_output) ? (matrixC4_8 + matrixC4_8_accum) : matrixC4_8;
assign matrixC4_9_added = (add_accum_to_output) ? (matrixC4_9 + matrixC4_9_accum) : matrixC4_9;
assign matrixC4_10_added = (add_accum_to_output) ? (matrixC4_10 + matrixC4_10_accum) : matrixC4_10;
assign matrixC4_11_added = (add_accum_to_output) ? (matrixC4_11 + matrixC4_11_accum) : matrixC4_11;
assign matrixC4_12_added = (add_accum_to_output) ? (matrixC4_12 + matrixC4_12_accum) : matrixC4_12;
assign matrixC4_13_added = (add_accum_to_output) ? (matrixC4_13 + matrixC4_13_accum) : matrixC4_13;
assign matrixC4_14_added = (add_accum_to_output) ? (matrixC4_14 + matrixC4_14_accum) : matrixC4_14;
assign matrixC4_15_added = (add_accum_to_output) ? (matrixC4_15 + matrixC4_15_accum) : matrixC4_15;
assign matrixC5_0_added = (add_accum_to_output) ? (matrixC5_0 + matrixC5_0_accum) : matrixC5_0;
assign matrixC5_1_added = (add_accum_to_output) ? (matrixC5_1 + matrixC5_1_accum) : matrixC5_1;
assign matrixC5_2_added = (add_accum_to_output) ? (matrixC5_2 + matrixC5_2_accum) : matrixC5_2;
assign matrixC5_3_added = (add_accum_to_output) ? (matrixC5_3 + matrixC5_3_accum) : matrixC5_3;
assign matrixC5_4_added = (add_accum_to_output) ? (matrixC5_4 + matrixC5_4_accum) : matrixC5_4;
assign matrixC5_5_added = (add_accum_to_output) ? (matrixC5_5 + matrixC5_5_accum) : matrixC5_5;
assign matrixC5_6_added = (add_accum_to_output) ? (matrixC5_6 + matrixC5_6_accum) : matrixC5_6;
assign matrixC5_7_added = (add_accum_to_output) ? (matrixC5_7 + matrixC5_7_accum) : matrixC5_7;
assign matrixC5_8_added = (add_accum_to_output) ? (matrixC5_8 + matrixC5_8_accum) : matrixC5_8;
assign matrixC5_9_added = (add_accum_to_output) ? (matrixC5_9 + matrixC5_9_accum) : matrixC5_9;
assign matrixC5_10_added = (add_accum_to_output) ? (matrixC5_10 + matrixC5_10_accum) : matrixC5_10;
assign matrixC5_11_added = (add_accum_to_output) ? (matrixC5_11 + matrixC5_11_accum) : matrixC5_11;
assign matrixC5_12_added = (add_accum_to_output) ? (matrixC5_12 + matrixC5_12_accum) : matrixC5_12;
assign matrixC5_13_added = (add_accum_to_output) ? (matrixC5_13 + matrixC5_13_accum) : matrixC5_13;
assign matrixC5_14_added = (add_accum_to_output) ? (matrixC5_14 + matrixC5_14_accum) : matrixC5_14;
assign matrixC5_15_added = (add_accum_to_output) ? (matrixC5_15 + matrixC5_15_accum) : matrixC5_15;
assign matrixC6_0_added = (add_accum_to_output) ? (matrixC6_0 + matrixC6_0_accum) : matrixC6_0;
assign matrixC6_1_added = (add_accum_to_output) ? (matrixC6_1 + matrixC6_1_accum) : matrixC6_1;
assign matrixC6_2_added = (add_accum_to_output) ? (matrixC6_2 + matrixC6_2_accum) : matrixC6_2;
assign matrixC6_3_added = (add_accum_to_output) ? (matrixC6_3 + matrixC6_3_accum) : matrixC6_3;
assign matrixC6_4_added = (add_accum_to_output) ? (matrixC6_4 + matrixC6_4_accum) : matrixC6_4;
assign matrixC6_5_added = (add_accum_to_output) ? (matrixC6_5 + matrixC6_5_accum) : matrixC6_5;
assign matrixC6_6_added = (add_accum_to_output) ? (matrixC6_6 + matrixC6_6_accum) : matrixC6_6;
assign matrixC6_7_added = (add_accum_to_output) ? (matrixC6_7 + matrixC6_7_accum) : matrixC6_7;
assign matrixC6_8_added = (add_accum_to_output) ? (matrixC6_8 + matrixC6_8_accum) : matrixC6_8;
assign matrixC6_9_added = (add_accum_to_output) ? (matrixC6_9 + matrixC6_9_accum) : matrixC6_9;
assign matrixC6_10_added = (add_accum_to_output) ? (matrixC6_10 + matrixC6_10_accum) : matrixC6_10;
assign matrixC6_11_added = (add_accum_to_output) ? (matrixC6_11 + matrixC6_11_accum) : matrixC6_11;
assign matrixC6_12_added = (add_accum_to_output) ? (matrixC6_12 + matrixC6_12_accum) : matrixC6_12;
assign matrixC6_13_added = (add_accum_to_output) ? (matrixC6_13 + matrixC6_13_accum) : matrixC6_13;
assign matrixC6_14_added = (add_accum_to_output) ? (matrixC6_14 + matrixC6_14_accum) : matrixC6_14;
assign matrixC6_15_added = (add_accum_to_output) ? (matrixC6_15 + matrixC6_15_accum) : matrixC6_15;
assign matrixC7_0_added = (add_accum_to_output) ? (matrixC7_0 + matrixC7_0_accum) : matrixC7_0;
assign matrixC7_1_added = (add_accum_to_output) ? (matrixC7_1 + matrixC7_1_accum) : matrixC7_1;
assign matrixC7_2_added = (add_accum_to_output) ? (matrixC7_2 + matrixC7_2_accum) : matrixC7_2;
assign matrixC7_3_added = (add_accum_to_output) ? (matrixC7_3 + matrixC7_3_accum) : matrixC7_3;
assign matrixC7_4_added = (add_accum_to_output) ? (matrixC7_4 + matrixC7_4_accum) : matrixC7_4;
assign matrixC7_5_added = (add_accum_to_output) ? (matrixC7_5 + matrixC7_5_accum) : matrixC7_5;
assign matrixC7_6_added = (add_accum_to_output) ? (matrixC7_6 + matrixC7_6_accum) : matrixC7_6;
assign matrixC7_7_added = (add_accum_to_output) ? (matrixC7_7 + matrixC7_7_accum) : matrixC7_7;
assign matrixC7_8_added = (add_accum_to_output) ? (matrixC7_8 + matrixC7_8_accum) : matrixC7_8;
assign matrixC7_9_added = (add_accum_to_output) ? (matrixC7_9 + matrixC7_9_accum) : matrixC7_9;
assign matrixC7_10_added = (add_accum_to_output) ? (matrixC7_10 + matrixC7_10_accum) : matrixC7_10;
assign matrixC7_11_added = (add_accum_to_output) ? (matrixC7_11 + matrixC7_11_accum) : matrixC7_11;
assign matrixC7_12_added = (add_accum_to_output) ? (matrixC7_12 + matrixC7_12_accum) : matrixC7_12;
assign matrixC7_13_added = (add_accum_to_output) ? (matrixC7_13 + matrixC7_13_accum) : matrixC7_13;
assign matrixC7_14_added = (add_accum_to_output) ? (matrixC7_14 + matrixC7_14_accum) : matrixC7_14;
assign matrixC7_15_added = (add_accum_to_output) ? (matrixC7_15 + matrixC7_15_accum) : matrixC7_15;
assign matrixC8_0_added = (add_accum_to_output) ? (matrixC8_0 + matrixC8_0_accum) : matrixC8_0;
assign matrixC8_1_added = (add_accum_to_output) ? (matrixC8_1 + matrixC8_1_accum) : matrixC8_1;
assign matrixC8_2_added = (add_accum_to_output) ? (matrixC8_2 + matrixC8_2_accum) : matrixC8_2;
assign matrixC8_3_added = (add_accum_to_output) ? (matrixC8_3 + matrixC8_3_accum) : matrixC8_3;
assign matrixC8_4_added = (add_accum_to_output) ? (matrixC8_4 + matrixC8_4_accum) : matrixC8_4;
assign matrixC8_5_added = (add_accum_to_output) ? (matrixC8_5 + matrixC8_5_accum) : matrixC8_5;
assign matrixC8_6_added = (add_accum_to_output) ? (matrixC8_6 + matrixC8_6_accum) : matrixC8_6;
assign matrixC8_7_added = (add_accum_to_output) ? (matrixC8_7 + matrixC8_7_accum) : matrixC8_7;
assign matrixC8_8_added = (add_accum_to_output) ? (matrixC8_8 + matrixC8_8_accum) : matrixC8_8;
assign matrixC8_9_added = (add_accum_to_output) ? (matrixC8_9 + matrixC8_9_accum) : matrixC8_9;
assign matrixC8_10_added = (add_accum_to_output) ? (matrixC8_10 + matrixC8_10_accum) : matrixC8_10;
assign matrixC8_11_added = (add_accum_to_output) ? (matrixC8_11 + matrixC8_11_accum) : matrixC8_11;
assign matrixC8_12_added = (add_accum_to_output) ? (matrixC8_12 + matrixC8_12_accum) : matrixC8_12;
assign matrixC8_13_added = (add_accum_to_output) ? (matrixC8_13 + matrixC8_13_accum) : matrixC8_13;
assign matrixC8_14_added = (add_accum_to_output) ? (matrixC8_14 + matrixC8_14_accum) : matrixC8_14;
assign matrixC8_15_added = (add_accum_to_output) ? (matrixC8_15 + matrixC8_15_accum) : matrixC8_15;
assign matrixC9_0_added = (add_accum_to_output) ? (matrixC9_0 + matrixC9_0_accum) : matrixC9_0;
assign matrixC9_1_added = (add_accum_to_output) ? (matrixC9_1 + matrixC9_1_accum) : matrixC9_1;
assign matrixC9_2_added = (add_accum_to_output) ? (matrixC9_2 + matrixC9_2_accum) : matrixC9_2;
assign matrixC9_3_added = (add_accum_to_output) ? (matrixC9_3 + matrixC9_3_accum) : matrixC9_3;
assign matrixC9_4_added = (add_accum_to_output) ? (matrixC9_4 + matrixC9_4_accum) : matrixC9_4;
assign matrixC9_5_added = (add_accum_to_output) ? (matrixC9_5 + matrixC9_5_accum) : matrixC9_5;
assign matrixC9_6_added = (add_accum_to_output) ? (matrixC9_6 + matrixC9_6_accum) : matrixC9_6;
assign matrixC9_7_added = (add_accum_to_output) ? (matrixC9_7 + matrixC9_7_accum) : matrixC9_7;
assign matrixC9_8_added = (add_accum_to_output) ? (matrixC9_8 + matrixC9_8_accum) : matrixC9_8;
assign matrixC9_9_added = (add_accum_to_output) ? (matrixC9_9 + matrixC9_9_accum) : matrixC9_9;
assign matrixC9_10_added = (add_accum_to_output) ? (matrixC9_10 + matrixC9_10_accum) : matrixC9_10;
assign matrixC9_11_added = (add_accum_to_output) ? (matrixC9_11 + matrixC9_11_accum) : matrixC9_11;
assign matrixC9_12_added = (add_accum_to_output) ? (matrixC9_12 + matrixC9_12_accum) : matrixC9_12;
assign matrixC9_13_added = (add_accum_to_output) ? (matrixC9_13 + matrixC9_13_accum) : matrixC9_13;
assign matrixC9_14_added = (add_accum_to_output) ? (matrixC9_14 + matrixC9_14_accum) : matrixC9_14;
assign matrixC9_15_added = (add_accum_to_output) ? (matrixC9_15 + matrixC9_15_accum) : matrixC9_15;
assign matrixC10_0_added = (add_accum_to_output) ? (matrixC10_0 + matrixC10_0_accum) : matrixC10_0;
assign matrixC10_1_added = (add_accum_to_output) ? (matrixC10_1 + matrixC10_1_accum) : matrixC10_1;
assign matrixC10_2_added = (add_accum_to_output) ? (matrixC10_2 + matrixC10_2_accum) : matrixC10_2;
assign matrixC10_3_added = (add_accum_to_output) ? (matrixC10_3 + matrixC10_3_accum) : matrixC10_3;
assign matrixC10_4_added = (add_accum_to_output) ? (matrixC10_4 + matrixC10_4_accum) : matrixC10_4;
assign matrixC10_5_added = (add_accum_to_output) ? (matrixC10_5 + matrixC10_5_accum) : matrixC10_5;
assign matrixC10_6_added = (add_accum_to_output) ? (matrixC10_6 + matrixC10_6_accum) : matrixC10_6;
assign matrixC10_7_added = (add_accum_to_output) ? (matrixC10_7 + matrixC10_7_accum) : matrixC10_7;
assign matrixC10_8_added = (add_accum_to_output) ? (matrixC10_8 + matrixC10_8_accum) : matrixC10_8;
assign matrixC10_9_added = (add_accum_to_output) ? (matrixC10_9 + matrixC10_9_accum) : matrixC10_9;
assign matrixC10_10_added = (add_accum_to_output) ? (matrixC10_10 + matrixC10_10_accum) : matrixC10_10;
assign matrixC10_11_added = (add_accum_to_output) ? (matrixC10_11 + matrixC10_11_accum) : matrixC10_11;
assign matrixC10_12_added = (add_accum_to_output) ? (matrixC10_12 + matrixC10_12_accum) : matrixC10_12;
assign matrixC10_13_added = (add_accum_to_output) ? (matrixC10_13 + matrixC10_13_accum) : matrixC10_13;
assign matrixC10_14_added = (add_accum_to_output) ? (matrixC10_14 + matrixC10_14_accum) : matrixC10_14;
assign matrixC10_15_added = (add_accum_to_output) ? (matrixC10_15 + matrixC10_15_accum) : matrixC10_15;
assign matrixC11_0_added = (add_accum_to_output) ? (matrixC11_0 + matrixC11_0_accum) : matrixC11_0;
assign matrixC11_1_added = (add_accum_to_output) ? (matrixC11_1 + matrixC11_1_accum) : matrixC11_1;
assign matrixC11_2_added = (add_accum_to_output) ? (matrixC11_2 + matrixC11_2_accum) : matrixC11_2;
assign matrixC11_3_added = (add_accum_to_output) ? (matrixC11_3 + matrixC11_3_accum) : matrixC11_3;
assign matrixC11_4_added = (add_accum_to_output) ? (matrixC11_4 + matrixC11_4_accum) : matrixC11_4;
assign matrixC11_5_added = (add_accum_to_output) ? (matrixC11_5 + matrixC11_5_accum) : matrixC11_5;
assign matrixC11_6_added = (add_accum_to_output) ? (matrixC11_6 + matrixC11_6_accum) : matrixC11_6;
assign matrixC11_7_added = (add_accum_to_output) ? (matrixC11_7 + matrixC11_7_accum) : matrixC11_7;
assign matrixC11_8_added = (add_accum_to_output) ? (matrixC11_8 + matrixC11_8_accum) : matrixC11_8;
assign matrixC11_9_added = (add_accum_to_output) ? (matrixC11_9 + matrixC11_9_accum) : matrixC11_9;
assign matrixC11_10_added = (add_accum_to_output) ? (matrixC11_10 + matrixC11_10_accum) : matrixC11_10;
assign matrixC11_11_added = (add_accum_to_output) ? (matrixC11_11 + matrixC11_11_accum) : matrixC11_11;
assign matrixC11_12_added = (add_accum_to_output) ? (matrixC11_12 + matrixC11_12_accum) : matrixC11_12;
assign matrixC11_13_added = (add_accum_to_output) ? (matrixC11_13 + matrixC11_13_accum) : matrixC11_13;
assign matrixC11_14_added = (add_accum_to_output) ? (matrixC11_14 + matrixC11_14_accum) : matrixC11_14;
assign matrixC11_15_added = (add_accum_to_output) ? (matrixC11_15 + matrixC11_15_accum) : matrixC11_15;
assign matrixC12_0_added = (add_accum_to_output) ? (matrixC12_0 + matrixC12_0_accum) : matrixC12_0;
assign matrixC12_1_added = (add_accum_to_output) ? (matrixC12_1 + matrixC12_1_accum) : matrixC12_1;
assign matrixC12_2_added = (add_accum_to_output) ? (matrixC12_2 + matrixC12_2_accum) : matrixC12_2;
assign matrixC12_3_added = (add_accum_to_output) ? (matrixC12_3 + matrixC12_3_accum) : matrixC12_3;
assign matrixC12_4_added = (add_accum_to_output) ? (matrixC12_4 + matrixC12_4_accum) : matrixC12_4;
assign matrixC12_5_added = (add_accum_to_output) ? (matrixC12_5 + matrixC12_5_accum) : matrixC12_5;
assign matrixC12_6_added = (add_accum_to_output) ? (matrixC12_6 + matrixC12_6_accum) : matrixC12_6;
assign matrixC12_7_added = (add_accum_to_output) ? (matrixC12_7 + matrixC12_7_accum) : matrixC12_7;
assign matrixC12_8_added = (add_accum_to_output) ? (matrixC12_8 + matrixC12_8_accum) : matrixC12_8;
assign matrixC12_9_added = (add_accum_to_output) ? (matrixC12_9 + matrixC12_9_accum) : matrixC12_9;
assign matrixC12_10_added = (add_accum_to_output) ? (matrixC12_10 + matrixC12_10_accum) : matrixC12_10;
assign matrixC12_11_added = (add_accum_to_output) ? (matrixC12_11 + matrixC12_11_accum) : matrixC12_11;
assign matrixC12_12_added = (add_accum_to_output) ? (matrixC12_12 + matrixC12_12_accum) : matrixC12_12;
assign matrixC12_13_added = (add_accum_to_output) ? (matrixC12_13 + matrixC12_13_accum) : matrixC12_13;
assign matrixC12_14_added = (add_accum_to_output) ? (matrixC12_14 + matrixC12_14_accum) : matrixC12_14;
assign matrixC12_15_added = (add_accum_to_output) ? (matrixC12_15 + matrixC12_15_accum) : matrixC12_15;
assign matrixC13_0_added = (add_accum_to_output) ? (matrixC13_0 + matrixC13_0_accum) : matrixC13_0;
assign matrixC13_1_added = (add_accum_to_output) ? (matrixC13_1 + matrixC13_1_accum) : matrixC13_1;
assign matrixC13_2_added = (add_accum_to_output) ? (matrixC13_2 + matrixC13_2_accum) : matrixC13_2;
assign matrixC13_3_added = (add_accum_to_output) ? (matrixC13_3 + matrixC13_3_accum) : matrixC13_3;
assign matrixC13_4_added = (add_accum_to_output) ? (matrixC13_4 + matrixC13_4_accum) : matrixC13_4;
assign matrixC13_5_added = (add_accum_to_output) ? (matrixC13_5 + matrixC13_5_accum) : matrixC13_5;
assign matrixC13_6_added = (add_accum_to_output) ? (matrixC13_6 + matrixC13_6_accum) : matrixC13_6;
assign matrixC13_7_added = (add_accum_to_output) ? (matrixC13_7 + matrixC13_7_accum) : matrixC13_7;
assign matrixC13_8_added = (add_accum_to_output) ? (matrixC13_8 + matrixC13_8_accum) : matrixC13_8;
assign matrixC13_9_added = (add_accum_to_output) ? (matrixC13_9 + matrixC13_9_accum) : matrixC13_9;
assign matrixC13_10_added = (add_accum_to_output) ? (matrixC13_10 + matrixC13_10_accum) : matrixC13_10;
assign matrixC13_11_added = (add_accum_to_output) ? (matrixC13_11 + matrixC13_11_accum) : matrixC13_11;
assign matrixC13_12_added = (add_accum_to_output) ? (matrixC13_12 + matrixC13_12_accum) : matrixC13_12;
assign matrixC13_13_added = (add_accum_to_output) ? (matrixC13_13 + matrixC13_13_accum) : matrixC13_13;
assign matrixC13_14_added = (add_accum_to_output) ? (matrixC13_14 + matrixC13_14_accum) : matrixC13_14;
assign matrixC13_15_added = (add_accum_to_output) ? (matrixC13_15 + matrixC13_15_accum) : matrixC13_15;
assign matrixC14_0_added = (add_accum_to_output) ? (matrixC14_0 + matrixC14_0_accum) : matrixC14_0;
assign matrixC14_1_added = (add_accum_to_output) ? (matrixC14_1 + matrixC14_1_accum) : matrixC14_1;
assign matrixC14_2_added = (add_accum_to_output) ? (matrixC14_2 + matrixC14_2_accum) : matrixC14_2;
assign matrixC14_3_added = (add_accum_to_output) ? (matrixC14_3 + matrixC14_3_accum) : matrixC14_3;
assign matrixC14_4_added = (add_accum_to_output) ? (matrixC14_4 + matrixC14_4_accum) : matrixC14_4;
assign matrixC14_5_added = (add_accum_to_output) ? (matrixC14_5 + matrixC14_5_accum) : matrixC14_5;
assign matrixC14_6_added = (add_accum_to_output) ? (matrixC14_6 + matrixC14_6_accum) : matrixC14_6;
assign matrixC14_7_added = (add_accum_to_output) ? (matrixC14_7 + matrixC14_7_accum) : matrixC14_7;
assign matrixC14_8_added = (add_accum_to_output) ? (matrixC14_8 + matrixC14_8_accum) : matrixC14_8;
assign matrixC14_9_added = (add_accum_to_output) ? (matrixC14_9 + matrixC14_9_accum) : matrixC14_9;
assign matrixC14_10_added = (add_accum_to_output) ? (matrixC14_10 + matrixC14_10_accum) : matrixC14_10;
assign matrixC14_11_added = (add_accum_to_output) ? (matrixC14_11 + matrixC14_11_accum) : matrixC14_11;
assign matrixC14_12_added = (add_accum_to_output) ? (matrixC14_12 + matrixC14_12_accum) : matrixC14_12;
assign matrixC14_13_added = (add_accum_to_output) ? (matrixC14_13 + matrixC14_13_accum) : matrixC14_13;
assign matrixC14_14_added = (add_accum_to_output) ? (matrixC14_14 + matrixC14_14_accum) : matrixC14_14;
assign matrixC14_15_added = (add_accum_to_output) ? (matrixC14_15 + matrixC14_15_accum) : matrixC14_15;
assign matrixC15_0_added = (add_accum_to_output) ? (matrixC15_0 + matrixC15_0_accum) : matrixC15_0;
assign matrixC15_1_added = (add_accum_to_output) ? (matrixC15_1 + matrixC15_1_accum) : matrixC15_1;
assign matrixC15_2_added = (add_accum_to_output) ? (matrixC15_2 + matrixC15_2_accum) : matrixC15_2;
assign matrixC15_3_added = (add_accum_to_output) ? (matrixC15_3 + matrixC15_3_accum) : matrixC15_3;
assign matrixC15_4_added = (add_accum_to_output) ? (matrixC15_4 + matrixC15_4_accum) : matrixC15_4;
assign matrixC15_5_added = (add_accum_to_output) ? (matrixC15_5 + matrixC15_5_accum) : matrixC15_5;
assign matrixC15_6_added = (add_accum_to_output) ? (matrixC15_6 + matrixC15_6_accum) : matrixC15_6;
assign matrixC15_7_added = (add_accum_to_output) ? (matrixC15_7 + matrixC15_7_accum) : matrixC15_7;
assign matrixC15_8_added = (add_accum_to_output) ? (matrixC15_8 + matrixC15_8_accum) : matrixC15_8;
assign matrixC15_9_added = (add_accum_to_output) ? (matrixC15_9 + matrixC15_9_accum) : matrixC15_9;
assign matrixC15_10_added = (add_accum_to_output) ? (matrixC15_10 + matrixC15_10_accum) : matrixC15_10;
assign matrixC15_11_added = (add_accum_to_output) ? (matrixC15_11 + matrixC15_11_accum) : matrixC15_11;
assign matrixC15_12_added = (add_accum_to_output) ? (matrixC15_12 + matrixC15_12_accum) : matrixC15_12;
assign matrixC15_13_added = (add_accum_to_output) ? (matrixC15_13 + matrixC15_13_accum) : matrixC15_13;
assign matrixC15_14_added = (add_accum_to_output) ? (matrixC15_14 + matrixC15_14_accum) : matrixC15_14;
assign matrixC15_15_added = (add_accum_to_output) ? (matrixC15_15 + matrixC15_15_accum) : matrixC15_15;

//////////////////////////////////////////////////////////////////////////
// Logic to capture matrix C data from the PEs and shift it out
//////////////////////////////////////////////////////////////////////////
//assign row_latch_en = (clk_cnt==(`MAT_MUL_SIZE + (a_loc+b_loc) * `BB_MAT_MUL_SIZE + 10 +  `NUM_CYCLES_IN_MAC - 1));
//Writing the line above to avoid multiplication:
//assign row_latch_en = (clk_cnt==(`MAT_MUL_SIZE + ((a_loc+b_loc) << `LOG2_MAT_MUL_SIZE) + 10 +  `NUM_CYCLES_IN_MAC - 1));

assign row_latch_en =  (save_output_to_accum) ?
                       ((clk_cnt == ((`MAT_MUL_SIZE<<2) - `MAT_MUL_SIZE -1 +`NUM_CYCLES_IN_MAC))) :
                       ((clk_cnt == ((`MAT_MUL_SIZE<<2) - `MAT_MUL_SIZE -2 +`NUM_CYCLES_IN_MAC)));
    
reg c_data_available;
reg [`AWIDTH-1:0] c_addr;
reg start_capturing_c_data;
integer counter;
reg [16*`DWIDTH-1:0] c_data_out;

//We need to reset the accumulators when the mat mul is done and when we are 
//done with final reduction to generated a tile's output.
assign reset_accum = done_mat_mul & start_capturing_c_data;

//If save_output_to_accum is asserted, that means we are not intending to shift
//out the outputs, because the outputs are still partial sums. 
wire condition_to_start_shifting_output;
assign condition_to_start_shifting_output = 
                          (save_output_to_accum && add_accum_to_output) ?
                          1'b0 : (
                          (save_output_to_accum) ?
                          1'b0 : (
                          (add_accum_to_output) ? 
                          row_latch_en:  
                          row_latch_en ));  

  
//For larger matmuls, this logic will have more entries in the case statement
always @(posedge clk) begin
  if (reset | ~start_mat_mul) begin
    start_capturing_c_data <= 1'b0;
    c_data_available <= 1'b0;
    c_addr <= address_mat_c-address_stride_c;
    c_data_out <= 0;
    counter <= 0;
  end else if (condition_to_start_shifting_output) begin
    start_capturing_c_data <= 1'b1;
    c_data_available <= 1'b1;
    c_addr <= c_addr + address_stride_c ;
    c_data_out <= {matrixC15_0_added, matrixC14_0_added, matrixC13_0_added, matrixC12_0_added, matrixC11_0_added, matrixC10_0_added, matrixC9_0_added, matrixC8_0_added, matrixC7_0_added, matrixC6_0_added, matrixC5_0_added, matrixC4_0_added, matrixC3_0_added, matrixC2_0_added, matrixC1_0_added, matrixC0_0_added};

    counter <= counter + 1;
  end else if (done_mat_mul) begin
    start_capturing_c_data <= 1'b0;
    c_data_available <= 1'b0;
    c_addr <= address_mat_c - address_stride_c;
    c_data_out <= 0;
  end 
  else if (start_capturing_c_data) begin
    c_data_available <= 1'b1;
    c_addr <= c_addr + address_stride_c; 
    counter <= counter + 1;
    case (counter)  //rest of the elements are captured here
    1: c_data_out <= {matrixC15_1_added, matrixC14_1_added, matrixC13_1_added, matrixC12_1_added, matrixC11_1_added, matrixC10_1_added, matrixC9_1_added, matrixC8_1_added, matrixC7_1_added, matrixC6_1_added, matrixC5_1_added, matrixC4_1_added, matrixC3_1_added, matrixC2_1_added, matrixC1_1_added, matrixC0_1_added};
    2: c_data_out <= {matrixC15_2_added, matrixC14_2_added, matrixC13_2_added, matrixC12_2_added, matrixC11_2_added, matrixC10_2_added, matrixC9_2_added, matrixC8_2_added, matrixC7_2_added, matrixC6_2_added, matrixC5_2_added, matrixC4_2_added, matrixC3_2_added, matrixC2_2_added, matrixC1_2_added, matrixC0_2_added};
    3: c_data_out <= {matrixC15_3_added, matrixC14_3_added, matrixC13_3_added, matrixC12_3_added, matrixC11_3_added, matrixC10_3_added, matrixC9_3_added, matrixC8_3_added, matrixC7_3_added, matrixC6_3_added, matrixC5_3_added, matrixC4_3_added, matrixC3_3_added, matrixC2_3_added, matrixC1_3_added, matrixC0_3_added};
    4: c_data_out <= {matrixC15_4_added, matrixC14_4_added, matrixC13_4_added, matrixC12_4_added, matrixC11_4_added, matrixC10_4_added, matrixC9_4_added, matrixC8_4_added, matrixC7_4_added, matrixC6_4_added, matrixC5_4_added, matrixC4_4_added, matrixC3_4_added, matrixC2_4_added, matrixC1_4_added, matrixC0_4_added};
    5: c_data_out <= {matrixC15_5_added, matrixC14_5_added, matrixC13_5_added, matrixC12_5_added, matrixC11_5_added, matrixC10_5_added, matrixC9_5_added, matrixC8_5_added, matrixC7_5_added, matrixC6_5_added, matrixC5_5_added, matrixC4_5_added, matrixC3_5_added, matrixC2_5_added, matrixC1_5_added, matrixC0_5_added};
    6: c_data_out <= {matrixC15_6_added, matrixC14_6_added, matrixC13_6_added, matrixC12_6_added, matrixC11_6_added, matrixC10_6_added, matrixC9_6_added, matrixC8_6_added, matrixC7_6_added, matrixC6_6_added, matrixC5_6_added, matrixC4_6_added, matrixC3_6_added, matrixC2_6_added, matrixC1_6_added, matrixC0_6_added};
    7: c_data_out <= {matrixC15_7_added, matrixC14_7_added, matrixC13_7_added, matrixC12_7_added, matrixC11_7_added, matrixC10_7_added, matrixC9_7_added, matrixC8_7_added, matrixC7_7_added, matrixC6_7_added, matrixC5_7_added, matrixC4_7_added, matrixC3_7_added, matrixC2_7_added, matrixC1_7_added, matrixC0_7_added};
    8: c_data_out <= {matrixC15_8_added, matrixC14_8_added, matrixC13_8_added, matrixC12_8_added, matrixC11_8_added, matrixC10_8_added, matrixC9_8_added, matrixC8_8_added, matrixC7_8_added, matrixC6_8_added, matrixC5_8_added, matrixC4_8_added, matrixC3_8_added, matrixC2_8_added, matrixC1_8_added, matrixC0_8_added};
    9: c_data_out <= {matrixC15_9_added, matrixC14_9_added, matrixC13_9_added, matrixC12_9_added, matrixC11_9_added, matrixC10_9_added, matrixC9_9_added, matrixC8_9_added, matrixC7_9_added, matrixC6_9_added, matrixC5_9_added, matrixC4_9_added, matrixC3_9_added, matrixC2_9_added, matrixC1_9_added, matrixC0_9_added};
    10: c_data_out <= {matrixC15_10_added, matrixC14_10_added, matrixC13_10_added, matrixC12_10_added, matrixC11_10_added, matrixC10_10_added, matrixC9_10_added, matrixC8_10_added, matrixC7_10_added, matrixC6_10_added, matrixC5_10_added, matrixC4_10_added, matrixC3_10_added, matrixC2_10_added, matrixC1_10_added, matrixC0_10_added};
    11: c_data_out <= {matrixC15_11_added, matrixC14_11_added, matrixC13_11_added, matrixC12_11_added, matrixC11_11_added, matrixC10_11_added, matrixC9_11_added, matrixC8_11_added, matrixC7_11_added, matrixC6_11_added, matrixC5_11_added, matrixC4_11_added, matrixC3_11_added, matrixC2_11_added, matrixC1_11_added, matrixC0_11_added};
    12: c_data_out <= {matrixC15_12_added, matrixC14_12_added, matrixC13_12_added, matrixC12_12_added, matrixC11_12_added, matrixC10_12_added, matrixC9_12_added, matrixC8_12_added, matrixC7_12_added, matrixC6_12_added, matrixC5_12_added, matrixC4_12_added, matrixC3_12_added, matrixC2_12_added, matrixC1_12_added, matrixC0_12_added};
    13: c_data_out <= {matrixC15_13_added, matrixC14_13_added, matrixC13_13_added, matrixC12_13_added, matrixC11_13_added, matrixC10_13_added, matrixC9_13_added, matrixC8_13_added, matrixC7_13_added, matrixC6_13_added, matrixC5_13_added, matrixC4_13_added, matrixC3_13_added, matrixC2_13_added, matrixC1_13_added, matrixC0_13_added};
    14: c_data_out <= {matrixC15_14_added, matrixC14_14_added, matrixC13_14_added, matrixC12_14_added, matrixC11_14_added, matrixC10_14_added, matrixC9_14_added, matrixC8_14_added, matrixC7_14_added, matrixC6_14_added, matrixC5_14_added, matrixC4_14_added, matrixC3_14_added, matrixC2_14_added, matrixC1_14_added, matrixC0_14_added};
    15: c_data_out <= {matrixC15_15_added, matrixC14_15_added, matrixC13_15_added, matrixC12_15_added, matrixC11_15_added, matrixC10_15_added, matrixC9_15_added, matrixC8_15_added, matrixC7_15_added, matrixC6_15_added, matrixC5_15_added, matrixC4_15_added, matrixC3_15_added, matrixC2_15_added, matrixC1_15_added, matrixC0_15_added};

        default: c_data_out <= 0;
    endcase
  end
end
//////////////////////////////////////////////////////////////////////////
// Instantiations of the actual PEs
//////////////////////////////////////////////////////////////////////////
//For larger matmul, more PEs will be needed
wire effective_rst;
assign effective_rst = reset | ~start_mat_mul;

processing_element pe0_0(.reset(effective_rst), .clk(clk),  .in_a(a0),      .in_b(b0),  .out_a(a0_0to0_1), .out_b(b0_0to1_0), .out_c(matrixC0_0));
processing_element pe0_1(.reset(effective_rst), .clk(clk),  .in_a(a0_0to0_1), .in_b(b1),  .out_a(a0_1to0_2), .out_b(b0_1to1_1), .out_c(matrixC0_1));
processing_element pe0_2(.reset(effective_rst), .clk(clk),  .in_a(a0_1to0_2), .in_b(b2),  .out_a(a0_2to0_3), .out_b(b0_2to1_2), .out_c(matrixC0_2));
processing_element pe0_3(.reset(effective_rst), .clk(clk),  .in_a(a0_2to0_3), .in_b(b3),  .out_a(a0_3to0_4), .out_b(b0_3to1_3), .out_c(matrixC0_3));
processing_element pe0_4(.reset(effective_rst), .clk(clk),  .in_a(a0_3to0_4), .in_b(b4),  .out_a(a0_4to0_5), .out_b(b0_4to1_4), .out_c(matrixC0_4));
processing_element pe0_5(.reset(effective_rst), .clk(clk),  .in_a(a0_4to0_5), .in_b(b5),  .out_a(a0_5to0_6), .out_b(b0_5to1_5), .out_c(matrixC0_5));
processing_element pe0_6(.reset(effective_rst), .clk(clk),  .in_a(a0_5to0_6), .in_b(b6),  .out_a(a0_6to0_7), .out_b(b0_6to1_6), .out_c(matrixC0_6));
processing_element pe0_7(.reset(effective_rst), .clk(clk),  .in_a(a0_6to0_7), .in_b(b7),  .out_a(a0_7to0_8), .out_b(b0_7to1_7), .out_c(matrixC0_7));
processing_element pe0_8(.reset(effective_rst), .clk(clk),  .in_a(a0_7to0_8), .in_b(b8),  .out_a(a0_8to0_9), .out_b(b0_8to1_8), .out_c(matrixC0_8));
processing_element pe0_9(.reset(effective_rst), .clk(clk),  .in_a(a0_8to0_9), .in_b(b9),  .out_a(a0_9to0_10), .out_b(b0_9to1_9), .out_c(matrixC0_9));
processing_element pe0_10(.reset(effective_rst), .clk(clk),  .in_a(a0_9to0_10), .in_b(b10),  .out_a(a0_10to0_11), .out_b(b0_10to1_10), .out_c(matrixC0_10));
processing_element pe0_11(.reset(effective_rst), .clk(clk),  .in_a(a0_10to0_11), .in_b(b11),  .out_a(a0_11to0_12), .out_b(b0_11to1_11), .out_c(matrixC0_11));
processing_element pe0_12(.reset(effective_rst), .clk(clk),  .in_a(a0_11to0_12), .in_b(b12),  .out_a(a0_12to0_13), .out_b(b0_12to1_12), .out_c(matrixC0_12));
processing_element pe0_13(.reset(effective_rst), .clk(clk),  .in_a(a0_12to0_13), .in_b(b13),  .out_a(a0_13to0_14), .out_b(b0_13to1_13), .out_c(matrixC0_13));
processing_element pe0_14(.reset(effective_rst), .clk(clk),  .in_a(a0_13to0_14), .in_b(b14),  .out_a(a0_14to0_15), .out_b(b0_14to1_14), .out_c(matrixC0_14));
processing_element pe0_15(.reset(effective_rst), .clk(clk),  .in_a(a0_14to0_15), .in_b(b15),  .out_a(a0_15to0_16), .out_b(b0_15to1_15), .out_c(matrixC0_15));

processing_element pe1_0(.reset(effective_rst), .clk(clk),  .in_a(a1), .in_b(b0_0to1_0),  .out_a(a1_0to1_1), .out_b(b1_0to2_0), .out_c(matrixC1_0));
processing_element pe2_0(.reset(effective_rst), .clk(clk),  .in_a(a2), .in_b(b1_0to2_0),  .out_a(a2_0to2_1), .out_b(b2_0to3_0), .out_c(matrixC2_0));
processing_element pe3_0(.reset(effective_rst), .clk(clk),  .in_a(a3), .in_b(b2_0to3_0),  .out_a(a3_0to3_1), .out_b(b3_0to4_0), .out_c(matrixC3_0));
processing_element pe4_0(.reset(effective_rst), .clk(clk),  .in_a(a4), .in_b(b3_0to4_0),  .out_a(a4_0to4_1), .out_b(b4_0to5_0), .out_c(matrixC4_0));
processing_element pe5_0(.reset(effective_rst), .clk(clk),  .in_a(a5), .in_b(b4_0to5_0),  .out_a(a5_0to5_1), .out_b(b5_0to6_0), .out_c(matrixC5_0));
processing_element pe6_0(.reset(effective_rst), .clk(clk),  .in_a(a6), .in_b(b5_0to6_0),  .out_a(a6_0to6_1), .out_b(b6_0to7_0), .out_c(matrixC6_0));
processing_element pe7_0(.reset(effective_rst), .clk(clk),  .in_a(a7), .in_b(b6_0to7_0),  .out_a(a7_0to7_1), .out_b(b7_0to8_0), .out_c(matrixC7_0));
processing_element pe8_0(.reset(effective_rst), .clk(clk),  .in_a(a8), .in_b(b7_0to8_0),  .out_a(a8_0to8_1), .out_b(b8_0to9_0), .out_c(matrixC8_0));
processing_element pe9_0(.reset(effective_rst), .clk(clk),  .in_a(a9), .in_b(b8_0to9_0),  .out_a(a9_0to9_1), .out_b(b9_0to10_0), .out_c(matrixC9_0));
processing_element pe10_0(.reset(effective_rst), .clk(clk),  .in_a(a10), .in_b(b9_0to10_0),  .out_a(a10_0to10_1), .out_b(b10_0to11_0), .out_c(matrixC10_0));
processing_element pe11_0(.reset(effective_rst), .clk(clk),  .in_a(a11), .in_b(b10_0to11_0),  .out_a(a11_0to11_1), .out_b(b11_0to12_0), .out_c(matrixC11_0));
processing_element pe12_0(.reset(effective_rst), .clk(clk),  .in_a(a12), .in_b(b11_0to12_0),  .out_a(a12_0to12_1), .out_b(b12_0to13_0), .out_c(matrixC12_0));
processing_element pe13_0(.reset(effective_rst), .clk(clk),  .in_a(a13), .in_b(b12_0to13_0),  .out_a(a13_0to13_1), .out_b(b13_0to14_0), .out_c(matrixC13_0));
processing_element pe14_0(.reset(effective_rst), .clk(clk),  .in_a(a14), .in_b(b13_0to14_0),  .out_a(a14_0to14_1), .out_b(b14_0to15_0), .out_c(matrixC14_0));
processing_element pe15_0(.reset(effective_rst), .clk(clk),  .in_a(a15), .in_b(b14_0to15_0),  .out_a(a15_0to15_1), .out_b(b15_0to16_0), .out_c(matrixC15_0));

processing_element pe1_1(.reset(effective_rst), .clk(clk),  .in_a(a1_0to1_1), .in_b(b0_1to1_1),  .out_a(a1_1to1_2), .out_b(b1_1to2_1), .out_c(matrixC1_1));
processing_element pe1_2(.reset(effective_rst), .clk(clk),  .in_a(a1_1to1_2), .in_b(b0_2to1_2),  .out_a(a1_2to1_3), .out_b(b1_2to2_2), .out_c(matrixC1_2));
processing_element pe1_3(.reset(effective_rst), .clk(clk),  .in_a(a1_2to1_3), .in_b(b0_3to1_3),  .out_a(a1_3to1_4), .out_b(b1_3to2_3), .out_c(matrixC1_3));
processing_element pe1_4(.reset(effective_rst), .clk(clk),  .in_a(a1_3to1_4), .in_b(b0_4to1_4),  .out_a(a1_4to1_5), .out_b(b1_4to2_4), .out_c(matrixC1_4));
processing_element pe1_5(.reset(effective_rst), .clk(clk),  .in_a(a1_4to1_5), .in_b(b0_5to1_5),  .out_a(a1_5to1_6), .out_b(b1_5to2_5), .out_c(matrixC1_5));
processing_element pe1_6(.reset(effective_rst), .clk(clk),  .in_a(a1_5to1_6), .in_b(b0_6to1_6),  .out_a(a1_6to1_7), .out_b(b1_6to2_6), .out_c(matrixC1_6));
processing_element pe1_7(.reset(effective_rst), .clk(clk),  .in_a(a1_6to1_7), .in_b(b0_7to1_7),  .out_a(a1_7to1_8), .out_b(b1_7to2_7), .out_c(matrixC1_7));
processing_element pe1_8(.reset(effective_rst), .clk(clk),  .in_a(a1_7to1_8), .in_b(b0_8to1_8),  .out_a(a1_8to1_9), .out_b(b1_8to2_8), .out_c(matrixC1_8));
processing_element pe1_9(.reset(effective_rst), .clk(clk),  .in_a(a1_8to1_9), .in_b(b0_9to1_9),  .out_a(a1_9to1_10), .out_b(b1_9to2_9), .out_c(matrixC1_9));
processing_element pe1_10(.reset(effective_rst), .clk(clk),  .in_a(a1_9to1_10), .in_b(b0_10to1_10),  .out_a(a1_10to1_11), .out_b(b1_10to2_10), .out_c(matrixC1_10));
processing_element pe1_11(.reset(effective_rst), .clk(clk),  .in_a(a1_10to1_11), .in_b(b0_11to1_11),  .out_a(a1_11to1_12), .out_b(b1_11to2_11), .out_c(matrixC1_11));
processing_element pe1_12(.reset(effective_rst), .clk(clk),  .in_a(a1_11to1_12), .in_b(b0_12to1_12),  .out_a(a1_12to1_13), .out_b(b1_12to2_12), .out_c(matrixC1_12));
processing_element pe1_13(.reset(effective_rst), .clk(clk),  .in_a(a1_12to1_13), .in_b(b0_13to1_13),  .out_a(a1_13to1_14), .out_b(b1_13to2_13), .out_c(matrixC1_13));
processing_element pe1_14(.reset(effective_rst), .clk(clk),  .in_a(a1_13to1_14), .in_b(b0_14to1_14),  .out_a(a1_14to1_15), .out_b(b1_14to2_14), .out_c(matrixC1_14));
processing_element pe1_15(.reset(effective_rst), .clk(clk),  .in_a(a1_14to1_15), .in_b(b0_15to1_15),  .out_a(a1_15to1_16), .out_b(b1_15to2_15), .out_c(matrixC1_15));
processing_element pe2_1(.reset(effective_rst), .clk(clk),  .in_a(a2_0to2_1), .in_b(b1_1to2_1),  .out_a(a2_1to2_2), .out_b(b2_1to3_1), .out_c(matrixC2_1));
processing_element pe2_2(.reset(effective_rst), .clk(clk),  .in_a(a2_1to2_2), .in_b(b1_2to2_2),  .out_a(a2_2to2_3), .out_b(b2_2to3_2), .out_c(matrixC2_2));
processing_element pe2_3(.reset(effective_rst), .clk(clk),  .in_a(a2_2to2_3), .in_b(b1_3to2_3),  .out_a(a2_3to2_4), .out_b(b2_3to3_3), .out_c(matrixC2_3));
processing_element pe2_4(.reset(effective_rst), .clk(clk),  .in_a(a2_3to2_4), .in_b(b1_4to2_4),  .out_a(a2_4to2_5), .out_b(b2_4to3_4), .out_c(matrixC2_4));
processing_element pe2_5(.reset(effective_rst), .clk(clk),  .in_a(a2_4to2_5), .in_b(b1_5to2_5),  .out_a(a2_5to2_6), .out_b(b2_5to3_5), .out_c(matrixC2_5));
processing_element pe2_6(.reset(effective_rst), .clk(clk),  .in_a(a2_5to2_6), .in_b(b1_6to2_6),  .out_a(a2_6to2_7), .out_b(b2_6to3_6), .out_c(matrixC2_6));
processing_element pe2_7(.reset(effective_rst), .clk(clk),  .in_a(a2_6to2_7), .in_b(b1_7to2_7),  .out_a(a2_7to2_8), .out_b(b2_7to3_7), .out_c(matrixC2_7));
processing_element pe2_8(.reset(effective_rst), .clk(clk),  .in_a(a2_7to2_8), .in_b(b1_8to2_8),  .out_a(a2_8to2_9), .out_b(b2_8to3_8), .out_c(matrixC2_8));
processing_element pe2_9(.reset(effective_rst), .clk(clk),  .in_a(a2_8to2_9), .in_b(b1_9to2_9),  .out_a(a2_9to2_10), .out_b(b2_9to3_9), .out_c(matrixC2_9));
processing_element pe2_10(.reset(effective_rst), .clk(clk),  .in_a(a2_9to2_10), .in_b(b1_10to2_10),  .out_a(a2_10to2_11), .out_b(b2_10to3_10), .out_c(matrixC2_10));
processing_element pe2_11(.reset(effective_rst), .clk(clk),  .in_a(a2_10to2_11), .in_b(b1_11to2_11),  .out_a(a2_11to2_12), .out_b(b2_11to3_11), .out_c(matrixC2_11));
processing_element pe2_12(.reset(effective_rst), .clk(clk),  .in_a(a2_11to2_12), .in_b(b1_12to2_12),  .out_a(a2_12to2_13), .out_b(b2_12to3_12), .out_c(matrixC2_12));
processing_element pe2_13(.reset(effective_rst), .clk(clk),  .in_a(a2_12to2_13), .in_b(b1_13to2_13),  .out_a(a2_13to2_14), .out_b(b2_13to3_13), .out_c(matrixC2_13));
processing_element pe2_14(.reset(effective_rst), .clk(clk),  .in_a(a2_13to2_14), .in_b(b1_14to2_14),  .out_a(a2_14to2_15), .out_b(b2_14to3_14), .out_c(matrixC2_14));
processing_element pe2_15(.reset(effective_rst), .clk(clk),  .in_a(a2_14to2_15), .in_b(b1_15to2_15),  .out_a(a2_15to2_16), .out_b(b2_15to3_15), .out_c(matrixC2_15));
processing_element pe3_1(.reset(effective_rst), .clk(clk),  .in_a(a3_0to3_1), .in_b(b2_1to3_1),  .out_a(a3_1to3_2), .out_b(b3_1to4_1), .out_c(matrixC3_1));
processing_element pe3_2(.reset(effective_rst), .clk(clk),  .in_a(a3_1to3_2), .in_b(b2_2to3_2),  .out_a(a3_2to3_3), .out_b(b3_2to4_2), .out_c(matrixC3_2));
processing_element pe3_3(.reset(effective_rst), .clk(clk),  .in_a(a3_2to3_3), .in_b(b2_3to3_3),  .out_a(a3_3to3_4), .out_b(b3_3to4_3), .out_c(matrixC3_3));
processing_element pe3_4(.reset(effective_rst), .clk(clk),  .in_a(a3_3to3_4), .in_b(b2_4to3_4),  .out_a(a3_4to3_5), .out_b(b3_4to4_4), .out_c(matrixC3_4));
processing_element pe3_5(.reset(effective_rst), .clk(clk),  .in_a(a3_4to3_5), .in_b(b2_5to3_5),  .out_a(a3_5to3_6), .out_b(b3_5to4_5), .out_c(matrixC3_5));
processing_element pe3_6(.reset(effective_rst), .clk(clk),  .in_a(a3_5to3_6), .in_b(b2_6to3_6),  .out_a(a3_6to3_7), .out_b(b3_6to4_6), .out_c(matrixC3_6));
processing_element pe3_7(.reset(effective_rst), .clk(clk),  .in_a(a3_6to3_7), .in_b(b2_7to3_7),  .out_a(a3_7to3_8), .out_b(b3_7to4_7), .out_c(matrixC3_7));
processing_element pe3_8(.reset(effective_rst), .clk(clk),  .in_a(a3_7to3_8), .in_b(b2_8to3_8),  .out_a(a3_8to3_9), .out_b(b3_8to4_8), .out_c(matrixC3_8));
processing_element pe3_9(.reset(effective_rst), .clk(clk),  .in_a(a3_8to3_9), .in_b(b2_9to3_9),  .out_a(a3_9to3_10), .out_b(b3_9to4_9), .out_c(matrixC3_9));
processing_element pe3_10(.reset(effective_rst), .clk(clk),  .in_a(a3_9to3_10), .in_b(b2_10to3_10),  .out_a(a3_10to3_11), .out_b(b3_10to4_10), .out_c(matrixC3_10));
processing_element pe3_11(.reset(effective_rst), .clk(clk),  .in_a(a3_10to3_11), .in_b(b2_11to3_11),  .out_a(a3_11to3_12), .out_b(b3_11to4_11), .out_c(matrixC3_11));
processing_element pe3_12(.reset(effective_rst), .clk(clk),  .in_a(a3_11to3_12), .in_b(b2_12to3_12),  .out_a(a3_12to3_13), .out_b(b3_12to4_12), .out_c(matrixC3_12));
processing_element pe3_13(.reset(effective_rst), .clk(clk),  .in_a(a3_12to3_13), .in_b(b2_13to3_13),  .out_a(a3_13to3_14), .out_b(b3_13to4_13), .out_c(matrixC3_13));
processing_element pe3_14(.reset(effective_rst), .clk(clk),  .in_a(a3_13to3_14), .in_b(b2_14to3_14),  .out_a(a3_14to3_15), .out_b(b3_14to4_14), .out_c(matrixC3_14));
processing_element pe3_15(.reset(effective_rst), .clk(clk),  .in_a(a3_14to3_15), .in_b(b2_15to3_15),  .out_a(a3_15to3_16), .out_b(b3_15to4_15), .out_c(matrixC3_15));
processing_element pe4_1(.reset(effective_rst), .clk(clk),  .in_a(a4_0to4_1), .in_b(b3_1to4_1),  .out_a(a4_1to4_2), .out_b(b4_1to5_1), .out_c(matrixC4_1));
processing_element pe4_2(.reset(effective_rst), .clk(clk),  .in_a(a4_1to4_2), .in_b(b3_2to4_2),  .out_a(a4_2to4_3), .out_b(b4_2to5_2), .out_c(matrixC4_2));
processing_element pe4_3(.reset(effective_rst), .clk(clk),  .in_a(a4_2to4_3), .in_b(b3_3to4_3),  .out_a(a4_3to4_4), .out_b(b4_3to5_3), .out_c(matrixC4_3));
processing_element pe4_4(.reset(effective_rst), .clk(clk),  .in_a(a4_3to4_4), .in_b(b3_4to4_4),  .out_a(a4_4to4_5), .out_b(b4_4to5_4), .out_c(matrixC4_4));
processing_element pe4_5(.reset(effective_rst), .clk(clk),  .in_a(a4_4to4_5), .in_b(b3_5to4_5),  .out_a(a4_5to4_6), .out_b(b4_5to5_5), .out_c(matrixC4_5));
processing_element pe4_6(.reset(effective_rst), .clk(clk),  .in_a(a4_5to4_6), .in_b(b3_6to4_6),  .out_a(a4_6to4_7), .out_b(b4_6to5_6), .out_c(matrixC4_6));
processing_element pe4_7(.reset(effective_rst), .clk(clk),  .in_a(a4_6to4_7), .in_b(b3_7to4_7),  .out_a(a4_7to4_8), .out_b(b4_7to5_7), .out_c(matrixC4_7));
processing_element pe4_8(.reset(effective_rst), .clk(clk),  .in_a(a4_7to4_8), .in_b(b3_8to4_8),  .out_a(a4_8to4_9), .out_b(b4_8to5_8), .out_c(matrixC4_8));
processing_element pe4_9(.reset(effective_rst), .clk(clk),  .in_a(a4_8to4_9), .in_b(b3_9to4_9),  .out_a(a4_9to4_10), .out_b(b4_9to5_9), .out_c(matrixC4_9));
processing_element pe4_10(.reset(effective_rst), .clk(clk),  .in_a(a4_9to4_10), .in_b(b3_10to4_10),  .out_a(a4_10to4_11), .out_b(b4_10to5_10), .out_c(matrixC4_10));
processing_element pe4_11(.reset(effective_rst), .clk(clk),  .in_a(a4_10to4_11), .in_b(b3_11to4_11),  .out_a(a4_11to4_12), .out_b(b4_11to5_11), .out_c(matrixC4_11));
processing_element pe4_12(.reset(effective_rst), .clk(clk),  .in_a(a4_11to4_12), .in_b(b3_12to4_12),  .out_a(a4_12to4_13), .out_b(b4_12to5_12), .out_c(matrixC4_12));
processing_element pe4_13(.reset(effective_rst), .clk(clk),  .in_a(a4_12to4_13), .in_b(b3_13to4_13),  .out_a(a4_13to4_14), .out_b(b4_13to5_13), .out_c(matrixC4_13));
processing_element pe4_14(.reset(effective_rst), .clk(clk),  .in_a(a4_13to4_14), .in_b(b3_14to4_14),  .out_a(a4_14to4_15), .out_b(b4_14to5_14), .out_c(matrixC4_14));
processing_element pe4_15(.reset(effective_rst), .clk(clk),  .in_a(a4_14to4_15), .in_b(b3_15to4_15),  .out_a(a4_15to4_16), .out_b(b4_15to5_15), .out_c(matrixC4_15));
processing_element pe5_1(.reset(effective_rst), .clk(clk),  .in_a(a5_0to5_1), .in_b(b4_1to5_1),  .out_a(a5_1to5_2), .out_b(b5_1to6_1), .out_c(matrixC5_1));
processing_element pe5_2(.reset(effective_rst), .clk(clk),  .in_a(a5_1to5_2), .in_b(b4_2to5_2),  .out_a(a5_2to5_3), .out_b(b5_2to6_2), .out_c(matrixC5_2));
processing_element pe5_3(.reset(effective_rst), .clk(clk),  .in_a(a5_2to5_3), .in_b(b4_3to5_3),  .out_a(a5_3to5_4), .out_b(b5_3to6_3), .out_c(matrixC5_3));
processing_element pe5_4(.reset(effective_rst), .clk(clk),  .in_a(a5_3to5_4), .in_b(b4_4to5_4),  .out_a(a5_4to5_5), .out_b(b5_4to6_4), .out_c(matrixC5_4));
processing_element pe5_5(.reset(effective_rst), .clk(clk),  .in_a(a5_4to5_5), .in_b(b4_5to5_5),  .out_a(a5_5to5_6), .out_b(b5_5to6_5), .out_c(matrixC5_5));
processing_element pe5_6(.reset(effective_rst), .clk(clk),  .in_a(a5_5to5_6), .in_b(b4_6to5_6),  .out_a(a5_6to5_7), .out_b(b5_6to6_6), .out_c(matrixC5_6));
processing_element pe5_7(.reset(effective_rst), .clk(clk),  .in_a(a5_6to5_7), .in_b(b4_7to5_7),  .out_a(a5_7to5_8), .out_b(b5_7to6_7), .out_c(matrixC5_7));
processing_element pe5_8(.reset(effective_rst), .clk(clk),  .in_a(a5_7to5_8), .in_b(b4_8to5_8),  .out_a(a5_8to5_9), .out_b(b5_8to6_8), .out_c(matrixC5_8));
processing_element pe5_9(.reset(effective_rst), .clk(clk),  .in_a(a5_8to5_9), .in_b(b4_9to5_9),  .out_a(a5_9to5_10), .out_b(b5_9to6_9), .out_c(matrixC5_9));
processing_element pe5_10(.reset(effective_rst), .clk(clk),  .in_a(a5_9to5_10), .in_b(b4_10to5_10),  .out_a(a5_10to5_11), .out_b(b5_10to6_10), .out_c(matrixC5_10));
processing_element pe5_11(.reset(effective_rst), .clk(clk),  .in_a(a5_10to5_11), .in_b(b4_11to5_11),  .out_a(a5_11to5_12), .out_b(b5_11to6_11), .out_c(matrixC5_11));
processing_element pe5_12(.reset(effective_rst), .clk(clk),  .in_a(a5_11to5_12), .in_b(b4_12to5_12),  .out_a(a5_12to5_13), .out_b(b5_12to6_12), .out_c(matrixC5_12));
processing_element pe5_13(.reset(effective_rst), .clk(clk),  .in_a(a5_12to5_13), .in_b(b4_13to5_13),  .out_a(a5_13to5_14), .out_b(b5_13to6_13), .out_c(matrixC5_13));
processing_element pe5_14(.reset(effective_rst), .clk(clk),  .in_a(a5_13to5_14), .in_b(b4_14to5_14),  .out_a(a5_14to5_15), .out_b(b5_14to6_14), .out_c(matrixC5_14));
processing_element pe5_15(.reset(effective_rst), .clk(clk),  .in_a(a5_14to5_15), .in_b(b4_15to5_15),  .out_a(a5_15to5_16), .out_b(b5_15to6_15), .out_c(matrixC5_15));
processing_element pe6_1(.reset(effective_rst), .clk(clk),  .in_a(a6_0to6_1), .in_b(b5_1to6_1),  .out_a(a6_1to6_2), .out_b(b6_1to7_1), .out_c(matrixC6_1));
processing_element pe6_2(.reset(effective_rst), .clk(clk),  .in_a(a6_1to6_2), .in_b(b5_2to6_2),  .out_a(a6_2to6_3), .out_b(b6_2to7_2), .out_c(matrixC6_2));
processing_element pe6_3(.reset(effective_rst), .clk(clk),  .in_a(a6_2to6_3), .in_b(b5_3to6_3),  .out_a(a6_3to6_4), .out_b(b6_3to7_3), .out_c(matrixC6_3));
processing_element pe6_4(.reset(effective_rst), .clk(clk),  .in_a(a6_3to6_4), .in_b(b5_4to6_4),  .out_a(a6_4to6_5), .out_b(b6_4to7_4), .out_c(matrixC6_4));
processing_element pe6_5(.reset(effective_rst), .clk(clk),  .in_a(a6_4to6_5), .in_b(b5_5to6_5),  .out_a(a6_5to6_6), .out_b(b6_5to7_5), .out_c(matrixC6_5));
processing_element pe6_6(.reset(effective_rst), .clk(clk),  .in_a(a6_5to6_6), .in_b(b5_6to6_6),  .out_a(a6_6to6_7), .out_b(b6_6to7_6), .out_c(matrixC6_6));
processing_element pe6_7(.reset(effective_rst), .clk(clk),  .in_a(a6_6to6_7), .in_b(b5_7to6_7),  .out_a(a6_7to6_8), .out_b(b6_7to7_7), .out_c(matrixC6_7));
processing_element pe6_8(.reset(effective_rst), .clk(clk),  .in_a(a6_7to6_8), .in_b(b5_8to6_8),  .out_a(a6_8to6_9), .out_b(b6_8to7_8), .out_c(matrixC6_8));
processing_element pe6_9(.reset(effective_rst), .clk(clk),  .in_a(a6_8to6_9), .in_b(b5_9to6_9),  .out_a(a6_9to6_10), .out_b(b6_9to7_9), .out_c(matrixC6_9));
processing_element pe6_10(.reset(effective_rst), .clk(clk),  .in_a(a6_9to6_10), .in_b(b5_10to6_10),  .out_a(a6_10to6_11), .out_b(b6_10to7_10), .out_c(matrixC6_10));
processing_element pe6_11(.reset(effective_rst), .clk(clk),  .in_a(a6_10to6_11), .in_b(b5_11to6_11),  .out_a(a6_11to6_12), .out_b(b6_11to7_11), .out_c(matrixC6_11));
processing_element pe6_12(.reset(effective_rst), .clk(clk),  .in_a(a6_11to6_12), .in_b(b5_12to6_12),  .out_a(a6_12to6_13), .out_b(b6_12to7_12), .out_c(matrixC6_12));
processing_element pe6_13(.reset(effective_rst), .clk(clk),  .in_a(a6_12to6_13), .in_b(b5_13to6_13),  .out_a(a6_13to6_14), .out_b(b6_13to7_13), .out_c(matrixC6_13));
processing_element pe6_14(.reset(effective_rst), .clk(clk),  .in_a(a6_13to6_14), .in_b(b5_14to6_14),  .out_a(a6_14to6_15), .out_b(b6_14to7_14), .out_c(matrixC6_14));
processing_element pe6_15(.reset(effective_rst), .clk(clk),  .in_a(a6_14to6_15), .in_b(b5_15to6_15),  .out_a(a6_15to6_16), .out_b(b6_15to7_15), .out_c(matrixC6_15));
processing_element pe7_1(.reset(effective_rst), .clk(clk),  .in_a(a7_0to7_1), .in_b(b6_1to7_1),  .out_a(a7_1to7_2), .out_b(b7_1to8_1), .out_c(matrixC7_1));
processing_element pe7_2(.reset(effective_rst), .clk(clk),  .in_a(a7_1to7_2), .in_b(b6_2to7_2),  .out_a(a7_2to7_3), .out_b(b7_2to8_2), .out_c(matrixC7_2));
processing_element pe7_3(.reset(effective_rst), .clk(clk),  .in_a(a7_2to7_3), .in_b(b6_3to7_3),  .out_a(a7_3to7_4), .out_b(b7_3to8_3), .out_c(matrixC7_3));
processing_element pe7_4(.reset(effective_rst), .clk(clk),  .in_a(a7_3to7_4), .in_b(b6_4to7_4),  .out_a(a7_4to7_5), .out_b(b7_4to8_4), .out_c(matrixC7_4));
processing_element pe7_5(.reset(effective_rst), .clk(clk),  .in_a(a7_4to7_5), .in_b(b6_5to7_5),  .out_a(a7_5to7_6), .out_b(b7_5to8_5), .out_c(matrixC7_5));
processing_element pe7_6(.reset(effective_rst), .clk(clk),  .in_a(a7_5to7_6), .in_b(b6_6to7_6),  .out_a(a7_6to7_7), .out_b(b7_6to8_6), .out_c(matrixC7_6));
processing_element pe7_7(.reset(effective_rst), .clk(clk),  .in_a(a7_6to7_7), .in_b(b6_7to7_7),  .out_a(a7_7to7_8), .out_b(b7_7to8_7), .out_c(matrixC7_7));
processing_element pe7_8(.reset(effective_rst), .clk(clk),  .in_a(a7_7to7_8), .in_b(b6_8to7_8),  .out_a(a7_8to7_9), .out_b(b7_8to8_8), .out_c(matrixC7_8));
processing_element pe7_9(.reset(effective_rst), .clk(clk),  .in_a(a7_8to7_9), .in_b(b6_9to7_9),  .out_a(a7_9to7_10), .out_b(b7_9to8_9), .out_c(matrixC7_9));
processing_element pe7_10(.reset(effective_rst), .clk(clk),  .in_a(a7_9to7_10), .in_b(b6_10to7_10),  .out_a(a7_10to7_11), .out_b(b7_10to8_10), .out_c(matrixC7_10));
processing_element pe7_11(.reset(effective_rst), .clk(clk),  .in_a(a7_10to7_11), .in_b(b6_11to7_11),  .out_a(a7_11to7_12), .out_b(b7_11to8_11), .out_c(matrixC7_11));
processing_element pe7_12(.reset(effective_rst), .clk(clk),  .in_a(a7_11to7_12), .in_b(b6_12to7_12),  .out_a(a7_12to7_13), .out_b(b7_12to8_12), .out_c(matrixC7_12));
processing_element pe7_13(.reset(effective_rst), .clk(clk),  .in_a(a7_12to7_13), .in_b(b6_13to7_13),  .out_a(a7_13to7_14), .out_b(b7_13to8_13), .out_c(matrixC7_13));
processing_element pe7_14(.reset(effective_rst), .clk(clk),  .in_a(a7_13to7_14), .in_b(b6_14to7_14),  .out_a(a7_14to7_15), .out_b(b7_14to8_14), .out_c(matrixC7_14));
processing_element pe7_15(.reset(effective_rst), .clk(clk),  .in_a(a7_14to7_15), .in_b(b6_15to7_15),  .out_a(a7_15to7_16), .out_b(b7_15to8_15), .out_c(matrixC7_15));
processing_element pe8_1(.reset(effective_rst), .clk(clk),  .in_a(a8_0to8_1), .in_b(b7_1to8_1),  .out_a(a8_1to8_2), .out_b(b8_1to9_1), .out_c(matrixC8_1));
processing_element pe8_2(.reset(effective_rst), .clk(clk),  .in_a(a8_1to8_2), .in_b(b7_2to8_2),  .out_a(a8_2to8_3), .out_b(b8_2to9_2), .out_c(matrixC8_2));
processing_element pe8_3(.reset(effective_rst), .clk(clk),  .in_a(a8_2to8_3), .in_b(b7_3to8_3),  .out_a(a8_3to8_4), .out_b(b8_3to9_3), .out_c(matrixC8_3));
processing_element pe8_4(.reset(effective_rst), .clk(clk),  .in_a(a8_3to8_4), .in_b(b7_4to8_4),  .out_a(a8_4to8_5), .out_b(b8_4to9_4), .out_c(matrixC8_4));
processing_element pe8_5(.reset(effective_rst), .clk(clk),  .in_a(a8_4to8_5), .in_b(b7_5to8_5),  .out_a(a8_5to8_6), .out_b(b8_5to9_5), .out_c(matrixC8_5));
processing_element pe8_6(.reset(effective_rst), .clk(clk),  .in_a(a8_5to8_6), .in_b(b7_6to8_6),  .out_a(a8_6to8_7), .out_b(b8_6to9_6), .out_c(matrixC8_6));
processing_element pe8_7(.reset(effective_rst), .clk(clk),  .in_a(a8_6to8_7), .in_b(b7_7to8_7),  .out_a(a8_7to8_8), .out_b(b8_7to9_7), .out_c(matrixC8_7));
processing_element pe8_8(.reset(effective_rst), .clk(clk),  .in_a(a8_7to8_8), .in_b(b7_8to8_8),  .out_a(a8_8to8_9), .out_b(b8_8to9_8), .out_c(matrixC8_8));
processing_element pe8_9(.reset(effective_rst), .clk(clk),  .in_a(a8_8to8_9), .in_b(b7_9to8_9),  .out_a(a8_9to8_10), .out_b(b8_9to9_9), .out_c(matrixC8_9));
processing_element pe8_10(.reset(effective_rst), .clk(clk),  .in_a(a8_9to8_10), .in_b(b7_10to8_10),  .out_a(a8_10to8_11), .out_b(b8_10to9_10), .out_c(matrixC8_10));
processing_element pe8_11(.reset(effective_rst), .clk(clk),  .in_a(a8_10to8_11), .in_b(b7_11to8_11),  .out_a(a8_11to8_12), .out_b(b8_11to9_11), .out_c(matrixC8_11));
processing_element pe8_12(.reset(effective_rst), .clk(clk),  .in_a(a8_11to8_12), .in_b(b7_12to8_12),  .out_a(a8_12to8_13), .out_b(b8_12to9_12), .out_c(matrixC8_12));
processing_element pe8_13(.reset(effective_rst), .clk(clk),  .in_a(a8_12to8_13), .in_b(b7_13to8_13),  .out_a(a8_13to8_14), .out_b(b8_13to9_13), .out_c(matrixC8_13));
processing_element pe8_14(.reset(effective_rst), .clk(clk),  .in_a(a8_13to8_14), .in_b(b7_14to8_14),  .out_a(a8_14to8_15), .out_b(b8_14to9_14), .out_c(matrixC8_14));
processing_element pe8_15(.reset(effective_rst), .clk(clk),  .in_a(a8_14to8_15), .in_b(b7_15to8_15),  .out_a(a8_15to8_16), .out_b(b8_15to9_15), .out_c(matrixC8_15));
processing_element pe9_1(.reset(effective_rst), .clk(clk),  .in_a(a9_0to9_1), .in_b(b8_1to9_1),  .out_a(a9_1to9_2), .out_b(b9_1to10_1), .out_c(matrixC9_1));
processing_element pe9_2(.reset(effective_rst), .clk(clk),  .in_a(a9_1to9_2), .in_b(b8_2to9_2),  .out_a(a9_2to9_3), .out_b(b9_2to10_2), .out_c(matrixC9_2));
processing_element pe9_3(.reset(effective_rst), .clk(clk),  .in_a(a9_2to9_3), .in_b(b8_3to9_3),  .out_a(a9_3to9_4), .out_b(b9_3to10_3), .out_c(matrixC9_3));
processing_element pe9_4(.reset(effective_rst), .clk(clk),  .in_a(a9_3to9_4), .in_b(b8_4to9_4),  .out_a(a9_4to9_5), .out_b(b9_4to10_4), .out_c(matrixC9_4));
processing_element pe9_5(.reset(effective_rst), .clk(clk),  .in_a(a9_4to9_5), .in_b(b8_5to9_5),  .out_a(a9_5to9_6), .out_b(b9_5to10_5), .out_c(matrixC9_5));
processing_element pe9_6(.reset(effective_rst), .clk(clk),  .in_a(a9_5to9_6), .in_b(b8_6to9_6),  .out_a(a9_6to9_7), .out_b(b9_6to10_6), .out_c(matrixC9_6));
processing_element pe9_7(.reset(effective_rst), .clk(clk),  .in_a(a9_6to9_7), .in_b(b8_7to9_7),  .out_a(a9_7to9_8), .out_b(b9_7to10_7), .out_c(matrixC9_7));
processing_element pe9_8(.reset(effective_rst), .clk(clk),  .in_a(a9_7to9_8), .in_b(b8_8to9_8),  .out_a(a9_8to9_9), .out_b(b9_8to10_8), .out_c(matrixC9_8));
processing_element pe9_9(.reset(effective_rst), .clk(clk),  .in_a(a9_8to9_9), .in_b(b8_9to9_9),  .out_a(a9_9to9_10), .out_b(b9_9to10_9), .out_c(matrixC9_9));
processing_element pe9_10(.reset(effective_rst), .clk(clk),  .in_a(a9_9to9_10), .in_b(b8_10to9_10),  .out_a(a9_10to9_11), .out_b(b9_10to10_10), .out_c(matrixC9_10));
processing_element pe9_11(.reset(effective_rst), .clk(clk),  .in_a(a9_10to9_11), .in_b(b8_11to9_11),  .out_a(a9_11to9_12), .out_b(b9_11to10_11), .out_c(matrixC9_11));
processing_element pe9_12(.reset(effective_rst), .clk(clk),  .in_a(a9_11to9_12), .in_b(b8_12to9_12),  .out_a(a9_12to9_13), .out_b(b9_12to10_12), .out_c(matrixC9_12));
processing_element pe9_13(.reset(effective_rst), .clk(clk),  .in_a(a9_12to9_13), .in_b(b8_13to9_13),  .out_a(a9_13to9_14), .out_b(b9_13to10_13), .out_c(matrixC9_13));
processing_element pe9_14(.reset(effective_rst), .clk(clk),  .in_a(a9_13to9_14), .in_b(b8_14to9_14),  .out_a(a9_14to9_15), .out_b(b9_14to10_14), .out_c(matrixC9_14));
processing_element pe9_15(.reset(effective_rst), .clk(clk),  .in_a(a9_14to9_15), .in_b(b8_15to9_15),  .out_a(a9_15to9_16), .out_b(b9_15to10_15), .out_c(matrixC9_15));
processing_element pe10_1(.reset(effective_rst), .clk(clk),  .in_a(a10_0to10_1), .in_b(b9_1to10_1),  .out_a(a10_1to10_2), .out_b(b10_1to11_1), .out_c(matrixC10_1));
processing_element pe10_2(.reset(effective_rst), .clk(clk),  .in_a(a10_1to10_2), .in_b(b9_2to10_2),  .out_a(a10_2to10_3), .out_b(b10_2to11_2), .out_c(matrixC10_2));
processing_element pe10_3(.reset(effective_rst), .clk(clk),  .in_a(a10_2to10_3), .in_b(b9_3to10_3),  .out_a(a10_3to10_4), .out_b(b10_3to11_3), .out_c(matrixC10_3));
processing_element pe10_4(.reset(effective_rst), .clk(clk),  .in_a(a10_3to10_4), .in_b(b9_4to10_4),  .out_a(a10_4to10_5), .out_b(b10_4to11_4), .out_c(matrixC10_4));
processing_element pe10_5(.reset(effective_rst), .clk(clk),  .in_a(a10_4to10_5), .in_b(b9_5to10_5),  .out_a(a10_5to10_6), .out_b(b10_5to11_5), .out_c(matrixC10_5));
processing_element pe10_6(.reset(effective_rst), .clk(clk),  .in_a(a10_5to10_6), .in_b(b9_6to10_6),  .out_a(a10_6to10_7), .out_b(b10_6to11_6), .out_c(matrixC10_6));
processing_element pe10_7(.reset(effective_rst), .clk(clk),  .in_a(a10_6to10_7), .in_b(b9_7to10_7),  .out_a(a10_7to10_8), .out_b(b10_7to11_7), .out_c(matrixC10_7));
processing_element pe10_8(.reset(effective_rst), .clk(clk),  .in_a(a10_7to10_8), .in_b(b9_8to10_8),  .out_a(a10_8to10_9), .out_b(b10_8to11_8), .out_c(matrixC10_8));
processing_element pe10_9(.reset(effective_rst), .clk(clk),  .in_a(a10_8to10_9), .in_b(b9_9to10_9),  .out_a(a10_9to10_10), .out_b(b10_9to11_9), .out_c(matrixC10_9));
processing_element pe10_10(.reset(effective_rst), .clk(clk),  .in_a(a10_9to10_10), .in_b(b9_10to10_10),  .out_a(a10_10to10_11), .out_b(b10_10to11_10), .out_c(matrixC10_10));
processing_element pe10_11(.reset(effective_rst), .clk(clk),  .in_a(a10_10to10_11), .in_b(b9_11to10_11),  .out_a(a10_11to10_12), .out_b(b10_11to11_11), .out_c(matrixC10_11));
processing_element pe10_12(.reset(effective_rst), .clk(clk),  .in_a(a10_11to10_12), .in_b(b9_12to10_12),  .out_a(a10_12to10_13), .out_b(b10_12to11_12), .out_c(matrixC10_12));
processing_element pe10_13(.reset(effective_rst), .clk(clk),  .in_a(a10_12to10_13), .in_b(b9_13to10_13),  .out_a(a10_13to10_14), .out_b(b10_13to11_13), .out_c(matrixC10_13));
processing_element pe10_14(.reset(effective_rst), .clk(clk),  .in_a(a10_13to10_14), .in_b(b9_14to10_14),  .out_a(a10_14to10_15), .out_b(b10_14to11_14), .out_c(matrixC10_14));
processing_element pe10_15(.reset(effective_rst), .clk(clk),  .in_a(a10_14to10_15), .in_b(b9_15to10_15),  .out_a(a10_15to10_16), .out_b(b10_15to11_15), .out_c(matrixC10_15));
processing_element pe11_1(.reset(effective_rst), .clk(clk),  .in_a(a11_0to11_1), .in_b(b10_1to11_1),  .out_a(a11_1to11_2), .out_b(b11_1to12_1), .out_c(matrixC11_1));
processing_element pe11_2(.reset(effective_rst), .clk(clk),  .in_a(a11_1to11_2), .in_b(b10_2to11_2),  .out_a(a11_2to11_3), .out_b(b11_2to12_2), .out_c(matrixC11_2));
processing_element pe11_3(.reset(effective_rst), .clk(clk),  .in_a(a11_2to11_3), .in_b(b10_3to11_3),  .out_a(a11_3to11_4), .out_b(b11_3to12_3), .out_c(matrixC11_3));
processing_element pe11_4(.reset(effective_rst), .clk(clk),  .in_a(a11_3to11_4), .in_b(b10_4to11_4),  .out_a(a11_4to11_5), .out_b(b11_4to12_4), .out_c(matrixC11_4));
processing_element pe11_5(.reset(effective_rst), .clk(clk),  .in_a(a11_4to11_5), .in_b(b10_5to11_5),  .out_a(a11_5to11_6), .out_b(b11_5to12_5), .out_c(matrixC11_5));
processing_element pe11_6(.reset(effective_rst), .clk(clk),  .in_a(a11_5to11_6), .in_b(b10_6to11_6),  .out_a(a11_6to11_7), .out_b(b11_6to12_6), .out_c(matrixC11_6));
processing_element pe11_7(.reset(effective_rst), .clk(clk),  .in_a(a11_6to11_7), .in_b(b10_7to11_7),  .out_a(a11_7to11_8), .out_b(b11_7to12_7), .out_c(matrixC11_7));
processing_element pe11_8(.reset(effective_rst), .clk(clk),  .in_a(a11_7to11_8), .in_b(b10_8to11_8),  .out_a(a11_8to11_9), .out_b(b11_8to12_8), .out_c(matrixC11_8));
processing_element pe11_9(.reset(effective_rst), .clk(clk),  .in_a(a11_8to11_9), .in_b(b10_9to11_9),  .out_a(a11_9to11_10), .out_b(b11_9to12_9), .out_c(matrixC11_9));
processing_element pe11_10(.reset(effective_rst), .clk(clk),  .in_a(a11_9to11_10), .in_b(b10_10to11_10),  .out_a(a11_10to11_11), .out_b(b11_10to12_10), .out_c(matrixC11_10));
processing_element pe11_11(.reset(effective_rst), .clk(clk),  .in_a(a11_10to11_11), .in_b(b10_11to11_11),  .out_a(a11_11to11_12), .out_b(b11_11to12_11), .out_c(matrixC11_11));
processing_element pe11_12(.reset(effective_rst), .clk(clk),  .in_a(a11_11to11_12), .in_b(b10_12to11_12),  .out_a(a11_12to11_13), .out_b(b11_12to12_12), .out_c(matrixC11_12));
processing_element pe11_13(.reset(effective_rst), .clk(clk),  .in_a(a11_12to11_13), .in_b(b10_13to11_13),  .out_a(a11_13to11_14), .out_b(b11_13to12_13), .out_c(matrixC11_13));
processing_element pe11_14(.reset(effective_rst), .clk(clk),  .in_a(a11_13to11_14), .in_b(b10_14to11_14),  .out_a(a11_14to11_15), .out_b(b11_14to12_14), .out_c(matrixC11_14));
processing_element pe11_15(.reset(effective_rst), .clk(clk),  .in_a(a11_14to11_15), .in_b(b10_15to11_15),  .out_a(a11_15to11_16), .out_b(b11_15to12_15), .out_c(matrixC11_15));
processing_element pe12_1(.reset(effective_rst), .clk(clk),  .in_a(a12_0to12_1), .in_b(b11_1to12_1),  .out_a(a12_1to12_2), .out_b(b12_1to13_1), .out_c(matrixC12_1));
processing_element pe12_2(.reset(effective_rst), .clk(clk),  .in_a(a12_1to12_2), .in_b(b11_2to12_2),  .out_a(a12_2to12_3), .out_b(b12_2to13_2), .out_c(matrixC12_2));
processing_element pe12_3(.reset(effective_rst), .clk(clk),  .in_a(a12_2to12_3), .in_b(b11_3to12_3),  .out_a(a12_3to12_4), .out_b(b12_3to13_3), .out_c(matrixC12_3));
processing_element pe12_4(.reset(effective_rst), .clk(clk),  .in_a(a12_3to12_4), .in_b(b11_4to12_4),  .out_a(a12_4to12_5), .out_b(b12_4to13_4), .out_c(matrixC12_4));
processing_element pe12_5(.reset(effective_rst), .clk(clk),  .in_a(a12_4to12_5), .in_b(b11_5to12_5),  .out_a(a12_5to12_6), .out_b(b12_5to13_5), .out_c(matrixC12_5));
processing_element pe12_6(.reset(effective_rst), .clk(clk),  .in_a(a12_5to12_6), .in_b(b11_6to12_6),  .out_a(a12_6to12_7), .out_b(b12_6to13_6), .out_c(matrixC12_6));
processing_element pe12_7(.reset(effective_rst), .clk(clk),  .in_a(a12_6to12_7), .in_b(b11_7to12_7),  .out_a(a12_7to12_8), .out_b(b12_7to13_7), .out_c(matrixC12_7));
processing_element pe12_8(.reset(effective_rst), .clk(clk),  .in_a(a12_7to12_8), .in_b(b11_8to12_8),  .out_a(a12_8to12_9), .out_b(b12_8to13_8), .out_c(matrixC12_8));
processing_element pe12_9(.reset(effective_rst), .clk(clk),  .in_a(a12_8to12_9), .in_b(b11_9to12_9),  .out_a(a12_9to12_10), .out_b(b12_9to13_9), .out_c(matrixC12_9));
processing_element pe12_10(.reset(effective_rst), .clk(clk),  .in_a(a12_9to12_10), .in_b(b11_10to12_10),  .out_a(a12_10to12_11), .out_b(b12_10to13_10), .out_c(matrixC12_10));
processing_element pe12_11(.reset(effective_rst), .clk(clk),  .in_a(a12_10to12_11), .in_b(b11_11to12_11),  .out_a(a12_11to12_12), .out_b(b12_11to13_11), .out_c(matrixC12_11));
processing_element pe12_12(.reset(effective_rst), .clk(clk),  .in_a(a12_11to12_12), .in_b(b11_12to12_12),  .out_a(a12_12to12_13), .out_b(b12_12to13_12), .out_c(matrixC12_12));
processing_element pe12_13(.reset(effective_rst), .clk(clk),  .in_a(a12_12to12_13), .in_b(b11_13to12_13),  .out_a(a12_13to12_14), .out_b(b12_13to13_13), .out_c(matrixC12_13));
processing_element pe12_14(.reset(effective_rst), .clk(clk),  .in_a(a12_13to12_14), .in_b(b11_14to12_14),  .out_a(a12_14to12_15), .out_b(b12_14to13_14), .out_c(matrixC12_14));
processing_element pe12_15(.reset(effective_rst), .clk(clk),  .in_a(a12_14to12_15), .in_b(b11_15to12_15),  .out_a(a12_15to12_16), .out_b(b12_15to13_15), .out_c(matrixC12_15));
processing_element pe13_1(.reset(effective_rst), .clk(clk),  .in_a(a13_0to13_1), .in_b(b12_1to13_1),  .out_a(a13_1to13_2), .out_b(b13_1to14_1), .out_c(matrixC13_1));
processing_element pe13_2(.reset(effective_rst), .clk(clk),  .in_a(a13_1to13_2), .in_b(b12_2to13_2),  .out_a(a13_2to13_3), .out_b(b13_2to14_2), .out_c(matrixC13_2));
processing_element pe13_3(.reset(effective_rst), .clk(clk),  .in_a(a13_2to13_3), .in_b(b12_3to13_3),  .out_a(a13_3to13_4), .out_b(b13_3to14_3), .out_c(matrixC13_3));
processing_element pe13_4(.reset(effective_rst), .clk(clk),  .in_a(a13_3to13_4), .in_b(b12_4to13_4),  .out_a(a13_4to13_5), .out_b(b13_4to14_4), .out_c(matrixC13_4));
processing_element pe13_5(.reset(effective_rst), .clk(clk),  .in_a(a13_4to13_5), .in_b(b12_5to13_5),  .out_a(a13_5to13_6), .out_b(b13_5to14_5), .out_c(matrixC13_5));
processing_element pe13_6(.reset(effective_rst), .clk(clk),  .in_a(a13_5to13_6), .in_b(b12_6to13_6),  .out_a(a13_6to13_7), .out_b(b13_6to14_6), .out_c(matrixC13_6));
processing_element pe13_7(.reset(effective_rst), .clk(clk),  .in_a(a13_6to13_7), .in_b(b12_7to13_7),  .out_a(a13_7to13_8), .out_b(b13_7to14_7), .out_c(matrixC13_7));
processing_element pe13_8(.reset(effective_rst), .clk(clk),  .in_a(a13_7to13_8), .in_b(b12_8to13_8),  .out_a(a13_8to13_9), .out_b(b13_8to14_8), .out_c(matrixC13_8));
processing_element pe13_9(.reset(effective_rst), .clk(clk),  .in_a(a13_8to13_9), .in_b(b12_9to13_9),  .out_a(a13_9to13_10), .out_b(b13_9to14_9), .out_c(matrixC13_9));
processing_element pe13_10(.reset(effective_rst), .clk(clk),  .in_a(a13_9to13_10), .in_b(b12_10to13_10),  .out_a(a13_10to13_11), .out_b(b13_10to14_10), .out_c(matrixC13_10));
processing_element pe13_11(.reset(effective_rst), .clk(clk),  .in_a(a13_10to13_11), .in_b(b12_11to13_11),  .out_a(a13_11to13_12), .out_b(b13_11to14_11), .out_c(matrixC13_11));
processing_element pe13_12(.reset(effective_rst), .clk(clk),  .in_a(a13_11to13_12), .in_b(b12_12to13_12),  .out_a(a13_12to13_13), .out_b(b13_12to14_12), .out_c(matrixC13_12));
processing_element pe13_13(.reset(effective_rst), .clk(clk),  .in_a(a13_12to13_13), .in_b(b12_13to13_13),  .out_a(a13_13to13_14), .out_b(b13_13to14_13), .out_c(matrixC13_13));
processing_element pe13_14(.reset(effective_rst), .clk(clk),  .in_a(a13_13to13_14), .in_b(b12_14to13_14),  .out_a(a13_14to13_15), .out_b(b13_14to14_14), .out_c(matrixC13_14));
processing_element pe13_15(.reset(effective_rst), .clk(clk),  .in_a(a13_14to13_15), .in_b(b12_15to13_15),  .out_a(a13_15to13_16), .out_b(b13_15to14_15), .out_c(matrixC13_15));
processing_element pe14_1(.reset(effective_rst), .clk(clk),  .in_a(a14_0to14_1), .in_b(b13_1to14_1),  .out_a(a14_1to14_2), .out_b(b14_1to15_1), .out_c(matrixC14_1));
processing_element pe14_2(.reset(effective_rst), .clk(clk),  .in_a(a14_1to14_2), .in_b(b13_2to14_2),  .out_a(a14_2to14_3), .out_b(b14_2to15_2), .out_c(matrixC14_2));
processing_element pe14_3(.reset(effective_rst), .clk(clk),  .in_a(a14_2to14_3), .in_b(b13_3to14_3),  .out_a(a14_3to14_4), .out_b(b14_3to15_3), .out_c(matrixC14_3));
processing_element pe14_4(.reset(effective_rst), .clk(clk),  .in_a(a14_3to14_4), .in_b(b13_4to14_4),  .out_a(a14_4to14_5), .out_b(b14_4to15_4), .out_c(matrixC14_4));
processing_element pe14_5(.reset(effective_rst), .clk(clk),  .in_a(a14_4to14_5), .in_b(b13_5to14_5),  .out_a(a14_5to14_6), .out_b(b14_5to15_5), .out_c(matrixC14_5));
processing_element pe14_6(.reset(effective_rst), .clk(clk),  .in_a(a14_5to14_6), .in_b(b13_6to14_6),  .out_a(a14_6to14_7), .out_b(b14_6to15_6), .out_c(matrixC14_6));
processing_element pe14_7(.reset(effective_rst), .clk(clk),  .in_a(a14_6to14_7), .in_b(b13_7to14_7),  .out_a(a14_7to14_8), .out_b(b14_7to15_7), .out_c(matrixC14_7));
processing_element pe14_8(.reset(effective_rst), .clk(clk),  .in_a(a14_7to14_8), .in_b(b13_8to14_8),  .out_a(a14_8to14_9), .out_b(b14_8to15_8), .out_c(matrixC14_8));
processing_element pe14_9(.reset(effective_rst), .clk(clk),  .in_a(a14_8to14_9), .in_b(b13_9to14_9),  .out_a(a14_9to14_10), .out_b(b14_9to15_9), .out_c(matrixC14_9));
processing_element pe14_10(.reset(effective_rst), .clk(clk),  .in_a(a14_9to14_10), .in_b(b13_10to14_10),  .out_a(a14_10to14_11), .out_b(b14_10to15_10), .out_c(matrixC14_10));
processing_element pe14_11(.reset(effective_rst), .clk(clk),  .in_a(a14_10to14_11), .in_b(b13_11to14_11),  .out_a(a14_11to14_12), .out_b(b14_11to15_11), .out_c(matrixC14_11));
processing_element pe14_12(.reset(effective_rst), .clk(clk),  .in_a(a14_11to14_12), .in_b(b13_12to14_12),  .out_a(a14_12to14_13), .out_b(b14_12to15_12), .out_c(matrixC14_12));
processing_element pe14_13(.reset(effective_rst), .clk(clk),  .in_a(a14_12to14_13), .in_b(b13_13to14_13),  .out_a(a14_13to14_14), .out_b(b14_13to15_13), .out_c(matrixC14_13));
processing_element pe14_14(.reset(effective_rst), .clk(clk),  .in_a(a14_13to14_14), .in_b(b13_14to14_14),  .out_a(a14_14to14_15), .out_b(b14_14to15_14), .out_c(matrixC14_14));
processing_element pe14_15(.reset(effective_rst), .clk(clk),  .in_a(a14_14to14_15), .in_b(b13_15to14_15),  .out_a(a14_15to14_16), .out_b(b14_15to15_15), .out_c(matrixC14_15));
processing_element pe15_1(.reset(effective_rst), .clk(clk),  .in_a(a15_0to15_1), .in_b(b14_1to15_1),  .out_a(a15_1to15_2), .out_b(b15_1to16_1), .out_c(matrixC15_1));
processing_element pe15_2(.reset(effective_rst), .clk(clk),  .in_a(a15_1to15_2), .in_b(b14_2to15_2),  .out_a(a15_2to15_3), .out_b(b15_2to16_2), .out_c(matrixC15_2));
processing_element pe15_3(.reset(effective_rst), .clk(clk),  .in_a(a15_2to15_3), .in_b(b14_3to15_3),  .out_a(a15_3to15_4), .out_b(b15_3to16_3), .out_c(matrixC15_3));
processing_element pe15_4(.reset(effective_rst), .clk(clk),  .in_a(a15_3to15_4), .in_b(b14_4to15_4),  .out_a(a15_4to15_5), .out_b(b15_4to16_4), .out_c(matrixC15_4));
processing_element pe15_5(.reset(effective_rst), .clk(clk),  .in_a(a15_4to15_5), .in_b(b14_5to15_5),  .out_a(a15_5to15_6), .out_b(b15_5to16_5), .out_c(matrixC15_5));
processing_element pe15_6(.reset(effective_rst), .clk(clk),  .in_a(a15_5to15_6), .in_b(b14_6to15_6),  .out_a(a15_6to15_7), .out_b(b15_6to16_6), .out_c(matrixC15_6));
processing_element pe15_7(.reset(effective_rst), .clk(clk),  .in_a(a15_6to15_7), .in_b(b14_7to15_7),  .out_a(a15_7to15_8), .out_b(b15_7to16_7), .out_c(matrixC15_7));
processing_element pe15_8(.reset(effective_rst), .clk(clk),  .in_a(a15_7to15_8), .in_b(b14_8to15_8),  .out_a(a15_8to15_9), .out_b(b15_8to16_8), .out_c(matrixC15_8));
processing_element pe15_9(.reset(effective_rst), .clk(clk),  .in_a(a15_8to15_9), .in_b(b14_9to15_9),  .out_a(a15_9to15_10), .out_b(b15_9to16_9), .out_c(matrixC15_9));
processing_element pe15_10(.reset(effective_rst), .clk(clk),  .in_a(a15_9to15_10), .in_b(b14_10to15_10),  .out_a(a15_10to15_11), .out_b(b15_10to16_10), .out_c(matrixC15_10));
processing_element pe15_11(.reset(effective_rst), .clk(clk),  .in_a(a15_10to15_11), .in_b(b14_11to15_11),  .out_a(a15_11to15_12), .out_b(b15_11to16_11), .out_c(matrixC15_11));
processing_element pe15_12(.reset(effective_rst), .clk(clk),  .in_a(a15_11to15_12), .in_b(b14_12to15_12),  .out_a(a15_12to15_13), .out_b(b15_12to16_12), .out_c(matrixC15_12));
processing_element pe15_13(.reset(effective_rst), .clk(clk),  .in_a(a15_12to15_13), .in_b(b14_13to15_13),  .out_a(a15_13to15_14), .out_b(b15_13to16_13), .out_c(matrixC15_13));
processing_element pe15_14(.reset(effective_rst), .clk(clk),  .in_a(a15_13to15_14), .in_b(b14_14to15_14),  .out_a(a15_14to15_15), .out_b(b15_14to16_14), .out_c(matrixC15_14));
processing_element pe15_15(.reset(effective_rst), .clk(clk),  .in_a(a15_14to15_15), .in_b(b14_15to15_15),  .out_a(a15_15to15_16), .out_b(b15_15to16_15), .out_c(matrixC15_15));
assign a_data_out = {a15_15to15_16,a14_15to14_16,a13_15to13_16,a12_15to12_16,a11_15to11_16,a10_15to10_16,a9_15to9_16,a8_15to8_16,a7_15to7_16,a6_15to6_16,a5_15to5_16,a4_15to4_16,a3_15to3_16,a2_15to2_16,a1_15to1_16,a0_15to0_16};
assign b_data_out = {b15_15to16_15,b15_14to16_14,b15_13to16_13,b15_12to16_12,b15_11to16_11,b15_10to16_10,b15_9to16_9,b15_8to16_8,b15_7to16_7,b15_6to16_6,b15_5to16_5,b15_4to16_4,b15_3to16_3,b15_2to16_2,b15_1to16_1,b15_0to16_0};

endmodule

module processing_element(
 reset, 
 clk, 
 in_a,
 in_b, 
 out_a, 
 out_b, 
 out_c
 );

 input reset;
 input clk;
 input  [`DWIDTH-1:0] in_a;
 input  [`DWIDTH-1:0] in_b;
 output [`DWIDTH-1:0] out_a;
 output [`DWIDTH-1:0] out_b;
 output [`DWIDTH-1:0] out_c;  //reduced precision

 reg [`DWIDTH-1:0] out_a;
 reg [`DWIDTH-1:0] out_b;
 wire [`DWIDTH-1:0] out_c;

 wire [`DWIDTH-1:0] out_mac;

 assign out_c = out_mac;

 seq_mac u_mac(.a(in_a), .b(in_b), .out(out_mac), .reset(reset), .clk(clk));

 always @(posedge clk)begin
    if(reset) begin
      out_a<=0;
      out_b<=0;
    end
    else begin  
      out_a<=in_a;
      out_b<=in_b;
    end
 end
 
endmodule

module seq_mac(a, b, out, reset, clk);
input [`DWIDTH-1:0] a;
input [`DWIDTH-1:0] b;
input reset;
input clk;
output [`DWIDTH-1:0] out;

reg [`DWIDTH-1:0] out;
wire [`DWIDTH-1:0] mul_out;
wire [`DWIDTH-1:0] add_out;

reg [`DWIDTH-1:0] a_flopped;
reg [`DWIDTH-1:0] b_flopped;

wire [2*`DWIDTH-1:0] mul_out_temp;
reg [2*`DWIDTH-1:0] mul_out_temp_reg;

always @(posedge clk) begin
  if (reset) begin
    a_flopped <= 0;
    b_flopped <= 0;
  end else begin
    a_flopped <= a;
    b_flopped <= b;
  end
end

//assign mul_out = a * b;
qmult mult_u1(.i_multiplicand(a_flopped), .i_multiplier(b_flopped), .o_result(mul_out_temp));

always @(posedge clk) begin
  if (reset) begin
    mul_out_temp_reg <= 0;
  end else begin
    mul_out_temp_reg <= mul_out_temp;
  end
end

//down cast the result
assign mul_out = 
    (mul_out_temp_reg[2*`DWIDTH-1] == 0) ?  //positive number
        (
           (|(mul_out_temp_reg[2*`DWIDTH-2 : `DWIDTH-1])) ?  //is any bit from 14:7 is 1, that means overlfow
             {mul_out_temp_reg[2*`DWIDTH-1] , {(`DWIDTH-1){1'b1}}} : //sign bit and then all 1s
             {mul_out_temp_reg[2*`DWIDTH-1] , mul_out_temp_reg[`DWIDTH-2:0]} 
        )
        : //negative number
        (
           (|(mul_out_temp_reg[2*`DWIDTH-2 : `DWIDTH-1])) ?  //is any bit from 14:7 is 0, that means overlfow
             {mul_out_temp_reg[2*`DWIDTH-1] , mul_out_temp_reg[`DWIDTH-2:0]} :
             {mul_out_temp_reg[2*`DWIDTH-1] , {(`DWIDTH-1){1'b0}}} //sign bit and then all 0s
        );


//we just truncate the higher bits of the product
//assign add_out = mul_out + out;
qadd add_u1(.a(out), .b(mul_out), .c(add_out));

always @(posedge clk) begin
  if (reset) begin
    out <= 0;
  end else begin
    out <= add_out;
  end
end

endmodule

module qmult(i_multiplicand,i_multiplier,o_result);
input [`DWIDTH-1:0] i_multiplicand;
input [`DWIDTH-1:0] i_multiplier;
output [2*`DWIDTH-1:0] o_result;

assign o_result = i_multiplicand * i_multiplier;
//DW02_mult #(`DWIDTH,`DWIDTH) u_mult(.A(i_multiplicand), .B(i_multiplier), .TC(1'b1), .PRODUCT(o_result));

endmodule

module qadd(a,b,c);
input [`DWIDTH-1:0] a;
input [`DWIDTH-1:0] b;
output [`DWIDTH-1:0] c;

assign c = a + b;
//DW01_add #(`DWIDTH) u_add(.A(a), .B(b), .CI(1'b0), .SUM(c), .CO());
endmodule
