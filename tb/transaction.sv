// --------------------- Transaction ---------------------
class transaction;
    rand bit [7:0] din; // input 
    rand bit       oper;
    rand bit       wr_en;
    rand bit       rd_en;
    bit      [7:0] dout;
    bit            full; 
    bit            empty;

    // display function
    function void display(input string component);
        $display("[%s]: wr_en: %b\t rd_en: %b\t din: %d", component, wr_en, rd_en, din);
    endfunction

    // constraint
    constraint control_oper{
        oper dist {0:=50, 1:=50};
        if(oper == 1'b1) {
            wr_en == 1'b1;
            rd_en == 1'b0;
        }
        else {
            wr_en == 1'b0;
            rd_en == 1'b1;
        }
    } 

    // deep copy
    function transaction copy();
        copy = new();
        copy.din   = this.din;
        copy.oper  = this.oper;
        copy.wr_en = this.wr_en;
        copy.rd_en = this.rd_en;
        copy.dout  = this.dout;
        copy.full  = this.full;
        copy.empty = this.empty;
    endfunction

endclass