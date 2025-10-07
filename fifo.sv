module fifo(
    input            clk, 
    input            rst, 
    input            wr_en,
    input            rd_en,
    input      [7:0] din,
    output reg [7:0] dout,
    output           full,
    output           empty
);

reg [3:0] wptr = 4'b0;
reg [3:0] rptr = 4'b0;
reg [4:0] cnt  = 5'b0;
reg [7:0] mem [15:0];

always@(posedge clk) begin
    if(rst == 1'b1) begin
        wptr <= 4'b0;
        rptr <= 4'b0;
        cnt  <= 5'b0;
    end

    else if(wr_en && !full) begin
        mem[wptr] <= din;
        wptr      <= wptr + 1'b1;
        cnt       <= cnt + 1'b1;
    end

    else if(rd_en && !empty) begin
        dout <= mem[rptr];
        rptr <= rptr + 1'b1;
        cnt  <= cnt  - 1'b1;
    end
end

assign empty = (cnt == 5'b0)  ? 1'b1 : 1'b0;
assign full  = (cnt == 5'd16) ? 1'b1 : 1'b0;

endmodule

// Interface
interface fifo_if;
    logic       clk;
    logic       rst;
    logic       wr_en;
    logic       rd_en;
    logic [7:0] din;
    logic [7:0] dout;
    logic       full;
    logic       empty;

endinterface
