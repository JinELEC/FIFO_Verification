// --------------------- Scoreboard ---------------------
class scoreboard;
    transaction tr;
    mailbox #(transaction) mbx;
    event sconext;

    // constructor
    function new(mailbox #(transaction) mbx);
        this.mbx = mbx;
    endfunction

    bit [7:0] din[$]; // queue
    bit [7:0] temp;   // temporarly store value

    task run();
        forever begin
            mbx.get(tr);
            if(tr.wr_en == 1'b1) begin
                if(tr.full != 1'b1) begin
                    din.push_back(tr.din); // input data from backward
                end
                else begin
                    $display("[SCO]: FIFO is full");
                end
            end

            if(tr.rd_en == 1'b1) begin
                if(tr.empty != 1'b1) begin
                    temp = din.pop_front(); // output data from front

                    if(tr.dout == temp) $display("[SCO]: Data Matched");
                    else $display("[SCO]: Data Mismatched");
                end
            else $display("[SCO]: FIFO is empty");
            end
        -> sconext;
        end
    endtask

endclass