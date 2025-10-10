// Testbench
class transaction;
  
  rand bit  oper;  
  bit       rd_en, wr_en;
  bit [7:0] din;
  bit [7:0] dout;            
  bit       full, empty;        
  
  constraint control_oper {  
    oper dist {1 :/ 50 , 0 :/ 50};  
  }
  
endclass
 
// Generator
class generator;
  
  transaction trans;           
  mailbox #(transaction) mbx; 
   
  int count = 0;            
  int i     = 0;               
  
  event next;               
  event done;               
   
  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
    trans = new();
  endfunction; 
 
  task run(); 
    repeat (count) begin
      assert (trans.randomize()) else $error("Randomization failed");
      i++;
      mbx.put(trans);
      @(next);
    end
    -> done;
  endtask
  
endclass

// Driver 
class driver;
  
  virtual fifo_if fif;     
  mailbox #(transaction) mbx;  
  transaction trans;     
 
  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
  endfunction; 
 
  task reset(); // reset DUT
    fif.rst   <= 1'b1;
    fif.rd_en <= 1'b0;
    fif.wr_en <= 1'b0;
    fif.din   <= 8'b0;
    repeat(5) @(posedge fif.clk);
    fif.rst   <= 1'b0;
    
  endtask
   
  task write();
    @(posedge fif.clk);
    fif.rst   <= 1'b0;
    fif.rd_en <= 1'b0;
    fif.wr_en <= 1'b1;
    fif.din   <= $urandom_range(1, 10);
    @(posedge fif.clk);
    fif.wr_en <= 1'b0;
    @(posedge fif.clk);
  endtask
  
  task read();  
    @(posedge fif.clk);
    fif.rst   <= 1'b0;
    fif.rd_en <= 1'b1;
    fif.wr_en <= 1'b0;
    @(posedge fif.clk);
    fif.rd_en <= 1'b0;       
    @(posedge fif.clk);
  endtask
  
  task run();
    forever begin
      mbx.get(trans);  
      if (trans.oper == 1'b1)
        write();
      else
        read();
    end
  endtask
  
endclass
 
// Monitor 
class monitor;
 
  virtual fifo_if fif;     
  mailbox #(transaction) mbx; 
  transaction trans;         
  
  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;     
  endfunction;
 
  task run();
    trans = new();
    
    forever begin
       repeat(2) @(posedge fif.clk);
            trans.wr_en = fif.wr_en;
            trans.rd_en = fif.rd_en;
            trans.full  = fif.full;
            trans.empty = fif.empty;
            @(posedge fif.clk);
            trans.dout  = fif.dout;
            mbx.put(trans);
    end
    
  endtask
  
endclass

// Scoreboard
class scoreboard;
  
  mailbox #(transaction) mbx;  
  transaction trans;         
  event next;
  
  bit [7:0] din[$];       
  bit [7:0] temp;         
  int err = 0;            
  
  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;     
  endfunction;
 
  task run();
    forever begin
      mbx.get(trans);
      if (trans.wr_en == 1'b1) begin
        if (trans.full == 1'b0) begin
          din.push_front(trans.din);
        end
        else begin
          $display("[SCO] : FIFO is full");
        end
      end
    
      if (trans.rd_en == 1'b1) begin
        if (trans.empty == 1'b0) begin  
          temp = din.pop_back();
          
          if (trans.dout == temp)
            $display("[SCO] : DATA MATCH");
          else begin
            $error("[SCO] : DATA MISMATCH");
            err++;
          end
        end
        else begin
          $display("[SCO] : FIFO IS EMPTY");
        end
      end
      -> next;
    end
  endtask
  
endclass
 
// Environment
class environment;
  generator gen;
  driver drv;
  monitor mon;
  scoreboard sco;
  
  mailbox #(transaction) gdmbx;  // gen - drv
  mailbox #(transaction) msmbx;  // mon - sco
  
  event next;
  
  virtual fifo_if fif;
  
  function new(virtual fifo_if fif);
    gdmbx = new();
    msmbx = new();
    
    gen = new(gdmbx);
    drv = new(gdmbx);
    mon = new(msmbx);
    sco = new(msmbx);
    
    this.fif = fif;
    drv.fif = this.fif;
    mon.fif = this.fif;
    
    gen.next = next;
    sco.next = next;
    
  endfunction
  
  task pre_test();
    drv.reset();
  endtask
  
  task test();
    fork
      gen.run();
      drv.run();
      mon.run();
      sco.run();
    join_any
  endtask
  
  task post_test();
    wait(gen.done.triggered);  
    $finish;
  endtask
  
  task run();
    pre_test();
    test();
    post_test();
  endtask
  
endclass

// Testbench Top 
module tb;
  fifo_if fif();
  fifo dut(
	  .clk      (fif.clk       ),
	  .rst      (fif.rst       ),
	  .wr_en    (fif.wr_en     ),
	  .rd_en    (fif.rd_en     ),
	  .din      (fif.din       ),
	  .dout     (fif.dout      ),
	  .full     (fif.full      ),
	  .empty    (fif.empty     )
	 );
    
  initial begin
    fif.clk <= 1'b0;
  end
    
  always #10 fif.clk <= ~fif.clk;
    
  environment env;
    
  initial begin
    env = new(fif);
    env.gen.count = 10;
    env.run();
  end
    
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
  end
   
endmodule
