module pool(
    input enable_pool,
    input in_data_available,
    input [`MAT_MUL_SIZE*`DWIDTH-1:0] inp_data,
    output [`MAT_MUL_SIZE*`DWIDTH-1:0] out_data,
    output out_data_available,
    input [`MASK_WIDTH-1:0] validity_mask,
    output done_pool,
    input clk,
    input reset
);

//This is a stub for now, until we get real logic here
assign out_data = inp_data;
assign out_data_available = in_data_available;
assign done_pool = 1;

//Dummy logic to make ODIN happy, until we get real logic here
reg [`MASK_WIDTH-1:0] temp;
always @(posedge clk) begin
    if (reset) begin
      temp <= 0;
    end
    else if (enable_pool) begin
      temp <= validity_mask;
    end
end

endmodule