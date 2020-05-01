`timescale 1ns/1ns
module top_tb();

reg clk;
reg reset;
wire resetn;
assign resetn = ~reset;

initial begin
  clk = 0;
  forever begin
    #10 clk = ~clk;
  end
end

reg        [`REG_ADDRWIDTH-1:0] PADDR;
reg                             PWRITE;
reg                             PSEL;
reg                             PENABLE;
reg     	 [`REG_DATAWIDTH-1:0] PWDATA;
wire 	  	 [`REG_DATAWIDTH-1:0] PRDATA;
wire	                          PREADY;

top u_top(
    .clk(clk),
    .clk_mem(clk),
    .reset(reset),
    .resetn(resetn),
    .PADDR(PADDR),
    .PWRITE(PWRITE),
    .PSEL(PSEL),
    .PENABLE(PENABLE),
    .PWDATA(PWDATA),
    .PRDATA(PRDATA),
    .PREADY(PREADY)
);

task write(input [`REG_ADDRWIDTH-1:0] addr, input [`REG_DATAWIDTH-1:0] data);
 begin
  @(negedge clk);
  PSEL = 1;
  PWRITE = 1;
  PADDR = addr;
  PWDATA = data;
	@(negedge clk);
  PENABLE = 1;
	@(negedge clk);
  PSEL = 0;
  PENABLE = 0;
  PWRITE = 0;
  PADDR = 0;
  PWDATA = 0;
  $display("%t: PADDR %h, PWDATA %h", $time, addr, data);
 end  
endtask

		 
task read(input [`REG_ADDRWIDTH-1:0] addr, output [`REG_DATAWIDTH-1:0] data);
begin 
	@(negedge clk);
	PSEL = 1;
	PWRITE = 0;
  PADDR = addr;
	@(negedge clk);
  PENABLE = 1;
	@(negedge clk);
  PSEL = 0;
  PENABLE = 0;
  data = PRDATA;
  PADDR = 0;
	$display("%t: PADDR %h, PRDATA %h",$time, addr,data);
end
endtask

//Temporary variables required in the test
reg [`REG_DATAWIDTH-1:0] rdata;
reg done;

initial begin
  //Reset conditions
  reset = 1;
	PSEL = 0;
	PWRITE = 0;
  PADDR = 0;
  PWDATA = 0;
  PENABLE = 0;
  done = 0;

  //Assert reset
  #55 reset = 0;

  //Wait for a clock or two
  #30;

  //Start the actual test
  
  $display("Set enables to 1");
  //enable_matmul = 1;
  //enable_norm = 1;
  //enable_activation = 1;
  //enable_pool = 1;
  write(`REG_ENABLES_ADDR, 32'h0000_000f);
  read(`REG_ENABLES_ADDR, rdata);

  $display("Configure the value of mean and inv_variance");
  //mean = 8'h01;
  //inv_var = 8'h01;
  write(`REG_MEAN_ADDR, 32'h0000_0001);
  write(`REG_INV_VAR_ADDR, 32'h0000_0001);

  $display("Start the TPU");
  //start = 1;
  write(`REG_STDN_TPU_ADDR, 32'h0000_0001);
  
  $display("Wait until TPU is done");
  do 
  begin
      read(`REG_STDN_TPU_ADDR, rdata);
      done = rdata[31];
  end 
  while (done == 0);
  
  $display("TPU is done now. Ending sim.");
  //A little bit of drain time before we finish
  #200;
  $finish;
end


//  A           B        Output       Output in hex
// 8 4 6 8   1 1 3 0   98 90 82 34    62 5A 52 22
// 3 3 3 7   0 1 4 3   75 63 51 26    4B 3F 33 1A
// 5 2 1 6   3 5 3 1   62 48 44 19    3E 30 2C 13
// 9 1 0 5   9 6 3 2   54 40 46 13    36 28 2E 0D

initial begin
  //A is stored in row major format
  force u_top.matrix_A.ram[0]  = 8'h08;
  force u_top.matrix_A.ram[1]  = 8'h03;
  force u_top.matrix_A.ram[2]  = 8'h05;
  force u_top.matrix_A.ram[3]  = 8'h09;
  force u_top.matrix_A.ram[4]  = 8'h04;
  force u_top.matrix_A.ram[5]  = 8'h03;
  force u_top.matrix_A.ram[6]  = 8'h02;
  force u_top.matrix_A.ram[7]  = 8'h01;
  force u_top.matrix_A.ram[8]  = 8'h06;
  force u_top.matrix_A.ram[9]  = 8'h03;
  force u_top.matrix_A.ram[10] = 8'h01;
  force u_top.matrix_A.ram[11] = 8'h00;
  force u_top.matrix_A.ram[12] = 8'h08;
  force u_top.matrix_A.ram[13] = 8'h07;
  force u_top.matrix_A.ram[14] = 8'h06;
  force u_top.matrix_A.ram[15] = 8'h05;
  //force u_top.matrix_A.ram[3:0] = '{32'h0506_0708, 32'h0001_0306, 32'h0102_0304, 32'h0905_0308};
  //bram_a.write(0, int('0x09050308',16))
  //bram_a.write(4, int('0x01020304',16))
  //bram_a.write(8, int('0x00010306',16))
  //bram_a.write(12, int('0x05060708',16))
  //bram_a.write(32764,int('0x00000000',16))
  
  
  //Last element is 0 (i think the logic requires this)
  force u_top.matrix_A.ram[`MEM_SIZE-1-3] = 8'h0;
  force u_top.matrix_A.ram[`MEM_SIZE-1-2] = 8'h0;
  force u_top.matrix_A.ram[`MEM_SIZE-1-1] = 8'h0;
  force u_top.matrix_A.ram[`MEM_SIZE-1-0] = 8'h0;
  //force u_top.matrix_A.ram[127] = 32'h0;

  //B is stored in col major format
  force u_top.matrix_B.ram[0]  = 8'h01;
  force u_top.matrix_B.ram[1]  = 8'h01;
  force u_top.matrix_B.ram[2]  = 8'h03;
  force u_top.matrix_B.ram[3]  = 8'h00;
  force u_top.matrix_B.ram[4]  = 8'h00;
  force u_top.matrix_B.ram[5]  = 8'h01;
  force u_top.matrix_B.ram[6]  = 8'h04;
  force u_top.matrix_B.ram[7]  = 8'h03;
  force u_top.matrix_B.ram[8]  = 8'h03;
  force u_top.matrix_B.ram[9]  = 8'h05;
  force u_top.matrix_B.ram[10] = 8'h03;
  force u_top.matrix_B.ram[11] = 8'h01;
  force u_top.matrix_B.ram[12] = 8'h09;
  force u_top.matrix_B.ram[13] = 8'h06;
  force u_top.matrix_B.ram[14] = 8'h03;
  force u_top.matrix_B.ram[15] = 8'h02;
  //force u_top.matrix_B.ram[3:0] = '{32'h0203_0609, 32'h0103_0503, 32'h0304_0100, 32'h0003_0101};

  //Last element is 0 (i think the logic requires this)
  force u_top.matrix_B.ram[`MEM_SIZE-1-3] = 8'h0;
  force u_top.matrix_B.ram[`MEM_SIZE-1-2] = 8'h0;
  force u_top.matrix_B.ram[`MEM_SIZE-1-1] = 8'h0;
  force u_top.matrix_B.ram[`MEM_SIZE-1-0] = 8'h0;
  //force u_top.matrix_B.ram[127] = 32'h0;
  //bram_b.write(0, int('0x00030101',16))
  //bram_b.write(4, int('0x03040100',16))
  //bram_b.write(8, int('0x01030503',16))
  //bram_b.write(12, int('0x02030609',16))
  //bram_b.write(32764,int('0x00000000',16))
end


initial begin
  $vcdpluson;
  $vcdplusmemon;
end

endmodule