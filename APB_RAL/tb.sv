`include "uvm_macros.svh"
import uvm_pkg::*;

class transaction extends uvm_sequence_item;
	`uvm_object_utils(transaction)
	rand bit[31:0] paddr;
	rand bit[31:0] pwdata;
	     bit[31:0] prdata;
	rand bit pwrite;

	function new(string name = "transaction");
		super.new(name);
	endfunction

	constraint c_paddr{paddr inside {0, 4, 8, 12, 16};}
endclass

class driver extends uvm_driver#(transaction);
	`uvm_component_utils(driver)

	virtual top_if vif;
	transaction tr;

	function new(string name = "driver", uvm_component parent = null);
		super.new(name,parent);
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		if(!uvm_config_db#(virtual top_if)::get(this,"","vif",vif))	
			`uvm_error("DRV", "Error Getting Interface Handle");
	endfunction

	virtual task write();
		@(posedge vif.pclk);
		vif.paddr <= tr.paddr;
		vif.pwdata <= tr.pwdata;
		vif.pwrite <= 1'b1;
		vif.psel <= 1'b1;
		@(posedge vif.pclk);
		vif.penable <= 1'b1;
		@(posedge vif.pclk);
		`uvm_info("DRV", $sformatf("MODE : WRITE DATA  PADDR : %0d, PWDATA : %0d", vif.paddr, vif.pwdata), UVM_NONE);
		@(posedge vif.pclk)
		vif.psel <= 1'b0;
		vif.penable <= 1'b0;
	endtask

	virtual task read();
		@(posedge vif.pclk)
		vif.paddr <= tr.paddr;
		vif.pwrite <= 1'b0;
		vif.psel <= 1'b1;
		@(posedge vif.pclk)
		vif.penable <= 1'b1;
		@(posedge vif.pclk);
		`uvm_info("DRV", $sformatf("MODE : READ PWDATA : %0d  PADDR : %0d PRDATA : %0d", vif.pwdata, vif.paddr, vif.prdata), UVM_NONE);
		@(posedge vif.pclk)
		vif.psel <= 1'b0;
		vif.penable <= 1'b0;
		tr.prdata <= vif.prdata;
	endtask

	virtual task run_phase(uvm_phase phase);
		bit[31:0] data;
		vif.presetn <= 1'b1;
		vif.psel <= 1'b0;
		vif.pwrite <= 1'b0;
		vif.paddr <= 1'b0;
		vif.pwdata <= 1'b0;
		vif.penable <= 1'b0;
		forever begin
			seq_item_port.get_next_item(tr);
			if(tr.pwrite) begin
				write();
			end
			else begin
				read();
			end
			seq_item_port.item_done();
		end
	endtask
endclass 

class monitor extends uvm_monitor;
	`uvm_component_utils(monitor)

	uvm_analysis_port #(transaction) mon_ap;
	virtual top_if vif;
	//transaction tr;

	function new(string name = "monitor", uvm_component parent = null);
		super.new(name, parent);
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		mon_ap = new("mon_ap", this);
		if(!uvm_config_db#(virtual top_if)::get(this,"","vif", vif))
			`uvm_error("DRV", "ERROR Getting Interface Handle");
		
	endfunction

	virtual task run_phase(uvm_phase phase);
		fork
			forever begin
				@(posedge vif.pclk);
				if(vif.psel && vif.penable && vif.presetn)begin
					transaction tr = transaction::type_id::create("tr");
					tr.paddr = vif.paddr;
					tr.pwrite = vif.pwrite;
					if(vif.pwrite)begin
						tr.pwdata = vif.pwdata;
						@(posedge vif.pclk);
						`uvm_info("MON",$sformatf("WRITE DATA  ADDR : %0d  PWDATA : %0d", vif.paddr, vif.pwdata),UVM_NONE);
					end
					else begin
						@(posedge vif.pclk);
						tr.prdata = vif.prdata;
						`uvm_info("MON",$sformatf("READ DATA  ADDR : %0d  PWDATA : %0d PRDATA : %0d", vif.paddr, vif.pwdata, vif.prdata),UVM_NONE);
					end
				mon_ap.write(tr);
				end				
			end
		join_none
	endtask
endclass

class sco extends uvm_scoreboard;
	`uvm_component_utils(sco)
	
	uvm_analysis_imp#(transaction,sco) recv;
	bit[31:0] arr[17];
	bit[31:0] temp;

	
	function new(input string inst = "sco", uvm_component parent = null);
		super.new(inst, parent);	
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		recv = new("recv", this);
	endfunction

	virtual function void write(transaction tr);
		if(tr.pwrite == 1)begin
			arr[tr.paddr] = tr.pwdata;
			`uvm_info("SCO", $sformatf("DATA STORED ADDR : %0d PWDATA : %0d", tr.paddr, tr.pwrite), UVM_NONE); 
		end

		else begin
			temp = arr[tr.paddr];
			if(temp == tr.prdata)begin
				`uvm_info("SCO", $sformatf("Test Passed ADDR : %0d DATA : %0d", tr.paddr, temp),UVM_NONE);
			end
			else begin
				`uvm_info("SCO", $sformatf("Test Failed ADDR : %0d DATA : %0d", tr.paddr, temp), UVM_NONE);
			end
		end
		$display("--------------------------------------------");
	endfunction
endclass

class agent extends uvm_agent;
	`uvm_component_utils(agent)
		
	function new(input string inst = "agent", uvm_component parent = null);
		super.new(inst, parent);
	endfunction

	driver d;
	uvm_sequencer#(transaction) seqr;
	monitor m;

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		d = driver::type_id::create("d",this);
		m = monitor::type_id::create("m",this);
		seqr = uvm_sequencer#(transaction)::type_id::create("seqr",this);

	endfunction

	virtual function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		d.seq_item_port.connect(seqr.seq_item_export);
	endfunction
	
endclass

class cntrl_reg extends uvm_reg;
	`uvm_object_utils(cntrl_reg)

	rand uvm_reg_field cntrl;
	
	function new(string name = "cntrl_reg");
		super.new(name, 4, build_coverage(UVM_NO_COVERAGE));		
	endfunction

	virtual function void build();
		cntrl = uvm_reg_field::type_id::create("cntrl");
		cntrl.configure(this, 4, 0,"RW", 0, 4'h0, 1, 1, 1);
	endfunction
endclass

class reg1_reg extends uvm_reg;
	`uvm_object_utils(reg1_reg)
	rand uvm_reg_field reg1;
	function new(string name = "reg1_reg");
		super.new(name, 32, build_coverage(UVM_NO_COVERAGE));
	endfunction

	function void build();
		reg1 = uvm_reg_field::type_id::create("reg1");
		reg1.configure(this, 32, 0, "RW", 0, 32'h0, 1, 1,1);
	endfunction
endclass

class reg2_reg extends uvm_reg;
	`uvm_object_utils(reg2_reg)
	rand uvm_reg_field reg2;
	function new(string name = "reg2_reg");
		super.new(name, 32, build_coverage(UVM_NO_COVERAGE));
	endfunction

	function void build();
		reg2 = uvm_reg_field::type_id::create("reg2");
		reg2.configure(this, 32, 0, "RW", 0, 32'h0, 1, 1,1);
	endfunction
endclass

class reg3_reg extends uvm_reg;
	`uvm_object_utils(reg3_reg)
	rand uvm_reg_field reg3;
	function new(string name = "reg3_reg");
		super.new(name, 32, build_coverage(UVM_NO_COVERAGE));
	endfunction

	function void build();
		reg3 = uvm_reg_field::type_id::create("reg3");
		reg3.configure(this, 32, 0, "RW", 0, 32'h0, 1, 1,1);
	endfunction
endclass

class reg4_reg extends uvm_reg;
	`uvm_object_utils(reg4_reg)
	rand uvm_reg_field reg4;
	function new(string name = "reg4_reg");
		super.new(name, 32, build_coverage(UVM_NO_COVERAGE));
	endfunction

	function void build();
		reg4 = uvm_reg_field::type_id::create("reg4");
		reg4.configure(this, 32, 0, "RW", 0, 32'h0, 1, 1,1);
	endfunction
endclass


class reg_block extends uvm_reg_block;
	`uvm_object_utils(reg_block)
	
	cntrl_reg cntrl_inst;
	reg1_reg reg1_inst;
	reg2_reg reg2_inst;
	reg3_reg reg3_inst;
	reg4_reg reg4_inst;

	function new(string name = "reg_block");
		super.new(name, build_coverage(UVM_NO_COVERAGE));
	endfunction

	virtual function void build();
		default_map = create_map("default_map", 0, 4,UVM_LITTLE_ENDIAN,0);

        	 cntrl_inst = cntrl_reg::type_id::create("cntrl_inst");
         	cntrl_inst.build();
         	cntrl_inst.configure(this,null);
  
 
 
         	reg1_inst = reg1_reg::type_id::create("reg1_inst");
         	reg1_inst.build();
        	reg1_inst.configure(this,null);
     
     
         	reg2_inst = reg2_reg::type_id::create("reg2_inst");
         	reg2_inst.build();
         	reg2_inst.configure(this,null);
     
     
         	reg3_inst = reg3_reg::type_id::create("reg3_inst");
        	reg3_inst.build();
         	reg3_inst.configure(this,null);
     
     
         	reg4_inst = reg4_reg::type_id::create("reg4_inst");
         	reg4_inst.build();
         	reg4_inst.configure(this,null);

        	default_map.add_reg(cntrl_inst	, 'h0, "RW");  // reg, offset, access
        	default_map.add_reg(reg1_inst	, 'h4, "RW");  // reg, offset, access
        	default_map.add_reg(reg2_inst	, 'h8, "RW");  // reg, offset, access
        	default_map.add_reg(reg3_inst	, 'hc, "RW");  // reg, offset, access
        	default_map.add_reg(reg4_inst	, 'h10, "RW");  // reg, offset, access
        	lock_model();
	endfunction
endclass

class top_adapter extends uvm_reg_adapter;
	`uvm_object_utils(top_adapter)

	function new(string name = "top_adapter");
		super.new(name);
	endfunction
	
	function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
		transaction tr;
		tr = transaction::type_id::create("tr");
		tr.pwrite = (rw.kind == UVM_WRITE)?1'b1:1'b0;
		tr.paddr = rw.addr;
		tr.pwdata = rw.data;

		return tr;
	endfunction

	function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
		transaction tr;

		assert ($cast(tr, bus_item));

		rw.kind = (tr.pwrite==1'b1)? UVM_WRITE : UVM_READ;
		rw.data = (tr.pwrite==1'b1)? tr.pwdata : tr.prdata;
		rw.addr = tr.paddr;
		rw.status = UVM_IS_OK; 
	endfunction
endclass

class env extends uvm_env;
	`uvm_component_utils(env)

	agent agent_inst;
	reg_block reg_model;
	top_adapter adapter_inst;
	uvm_reg_predictor #(transaction) predictor_inst;
	sco s;

	function new(string name = "env", uvm_component parent=null);
		super.new(name,parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		agent_inst = agent::type_id::create("agent_inst",this);
		s = sco::type_id::create("s",this);
		reg_model = reg_block::type_id::create("reg_model");
		reg_model.build();

		predictor_inst = uvm_reg_predictor#(transaction)::type_id::create("predictor_inst",this);
		adapter_inst = top_adapter::type_id::create("adapter_inst");
	endfunction

	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);

		agent_inst.m.mon_ap.connect(s.recv);
		agent_inst.m.mon_ap.connect(predictor_inst.bus_in);

		reg_model.default_map.set_sequencer(.sequencer(agent_inst.seqr), .adapter(adapter_inst));
		reg_model.default_map.set_base_addr(0);
		
		predictor_inst.map = reg_model.default_map;
		predictor_inst.adapter = adapter_inst;
	endfunction
endclass

class cntrl_wr extends uvm_sequence;
	`uvm_object_utils(cntrl_wr)

	reg_block regmodel;	

	function new(string name = "cntrl_wr");
		super.new(name);
	endfunction
	
	task body();
		uvm_status_e status;	
		bit[3:0] wdata;
		for(int i =0; i < 5; i++)begin
			wdata = $urandom();
			regmodel.cntrl_inst.write(status,wdata);
		end
	endtask
	
endclass

class cntrl_rd extends uvm_sequence;
	`uvm_object_utils(cntrl_rd)

	reg_block regmodel;	

	function new(string name = "cntrl_rd");
		super.new(name);
	endfunction
	
	task body();
		uvm_status_e status;	
		bit[3:0] rdata;
		for(int i =0; i < 5; i++)begin
			regmodel.cntrl_inst.read(status,rdata);
		end
	endtask
	
endclass

class reg1_wr extends uvm_sequence;
	`uvm_object_utils(reg1_wr)

	reg_block regmodel;
	function new(string name = "reg1_wr");
		super.new(name);
	endfunction

	task body();
		uvm_status_e status;
		bit[3:0] wdata;

		for(int i = 0; i<5; i++)begin
			wdata = $urandom();
			regmodel.reg1_inst.write(status, wdata);
		end
	endtask
endclass

class reg1_rd extends uvm_sequence;
	`uvm_object_utils(reg1_rd)

	reg_block regmodel;
	function new(string name = "reg1_rd");
		super.new(name);
	endfunction

	task body();
		uvm_status_e status;
		bit[3:0] rdata;

		for(int i = 0; i<5; i++)begin
			//wdata = $urandom();
			regmodel.reg1_inst.read(status, rdata);
		end
	endtask
endclass

class reg2_wr extends uvm_sequence;
	`uvm_object_utils(reg2_wr)

	reg_block regmodel;
	function new(string name = "reg2_wr");
		super.new(name);
	endfunction

	task body();
		uvm_status_e status;
		bit[3:0] wdata;

		for(int i = 0; i<5; i++)begin
			wdata = $urandom();
			regmodel.reg2_inst.write(status, wdata);
		end
	endtask
endclass

class reg2_rd extends uvm_sequence;
	`uvm_object_utils(reg2_rd)

	reg_block regmodel;
	function new(string name = "reg2_rd");
		super.new(name);
	endfunction

	task body();
		uvm_status_e status;
		bit[3:0] rdata;

		for(int i = 0; i<5; i++)begin
			//wdata = $urandom();
			regmodel.reg2_inst.read(status, rdata);
		end
	endtask
endclass

class reg3_wr extends uvm_sequence;
	`uvm_object_utils(reg3_wr)

	reg_block regmodel;
	function new(string name = "reg3_wr");
		super.new(name);
	endfunction

	task body();
		uvm_status_e status;
		bit[3:0] wdata;

		for(int i = 0; i<5; i++)begin
			wdata = $urandom();
			regmodel.reg3_inst.write(status, wdata);
		end
	endtask
endclass

class reg3_rd extends uvm_sequence;
	`uvm_object_utils(reg3_rd)

	reg_block regmodel;
	function new(string name = "reg3_rd");
		super.new(name);
	endfunction

	task body();
		uvm_status_e status;
		bit[3:0] rdata;

		for(int i = 0; i<5; i++)begin
			//wdata = $urandom();
			regmodel.reg3_inst.read(status, rdata);
		end
	endtask
endclass

class reg4_wr extends uvm_sequence;
	`uvm_object_utils(reg4_wr)

	reg_block regmodel;
	function new(string name = "reg4_wr");
		super.new(name);
	endfunction

	task body();
		uvm_status_e status;
		bit[3:0] wdata;

		for(int i = 0; i<5; i++)begin
			wdata = $urandom();
			regmodel.reg4_inst.write(status, wdata);
		end
	endtask
endclass

class reg4_rd extends uvm_sequence;
	`uvm_object_utils(reg4_rd)

	reg_block regmodel;
	function new(string name = "reg4_rd");
		super.new(name);
	endfunction

	task body();
		uvm_status_e status;
		bit[3:0] rdata;

		for(int i = 0; i<5; i++)begin
			//wdata = $urandom();
			regmodel.reg4_inst.read(status, rdata);
		end
	endtask
endclass

class test extends uvm_test;
	`uvm_component_utils(test)

	function new(input string inst = "test", uvm_component parent = null);
		super.new(inst,parent);
	endfunction

	env e;
	
	cntrl_wr cwr; cntrl_rd crd;
	reg1_wr r1wr; reg1_rd r1rd;
	reg2_wr r2wr; reg2_rd r2rd;
	reg3_wr r3wr; reg3_rd r3rd;
	reg4_wr r4wr; reg4_rd r4rd;

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		e = env::type_id::create("e",this);

		cwr = cntrl_wr::type_id::create("cwr");
		crd = cntrl_rd::type_id::create("crd");

		r1wr = reg1_wr::type_id::create("r1wr");
		r1rd = reg1_rd::type_id::create("r1rd");

		r2wr = reg2_wr::type_id::create("r2wr");
		r2rd = reg2_rd::type_id::create("r2rd");

		r3wr = reg3_wr::type_id::create("r3wr");
		r3rd = reg3_rd::type_id::create("r3rd");

		r4wr = reg4_wr::type_id::create("r4wr");
		r4rd = reg4_rd::type_id::create("r4rd");
	endfunction 

	virtual task run_phase(uvm_phase phase);
		phase.raise_objection(this);

		cwr.regmodel = e.reg_model;
		cwr.start(e.agent_inst.seqr);

		crd.regmodel = e.reg_model;
		crd.start(e.agent_inst.seqr);
  
  assert(r1wr.randomize());
  r1wr.regmodel = e.reg_model;
  r1wr.start(e.agent_inst.seqr);
  
  /////////////////read from control reg
  assert(r1rd.randomize());
  r1rd.regmodel = e.reg_model;
  r1rd.start(e.agent_inst.seqr);
 
 
  
  assert(r2wr.randomize());
  r2wr.regmodel = e.reg_model;
  r2wr.start(e.agent_inst.seqr);
  
  /////////////////read from control reg
  assert(r2rd.randomize());
  r2rd.regmodel = e.reg_model;
  r2rd.start(e.agent_inst.seqr);
 
  
  assert(r3wr.randomize());
  r3wr.regmodel = e.reg_model;
  r3wr.start(e.agent_inst.seqr);
  
  /////////////////read from control reg
  assert(r3rd.randomize());
  r3rd.regmodel = e.reg_model;
  r3rd.start(e.agent_inst.seqr);
  
  assert(r4wr.randomize());
  r4wr.regmodel = e.reg_model;
  r4wr.start(e.agent_inst.seqr);
  
  /////////////////read from control reg
  assert(r4rd.randomize());
  r4rd.regmodel = e.reg_model;
  r4rd.start(e.agent_inst.seqr);

		phase.drop_objection(this);
		phase.phase_done.set_drain_time(this, 200);
	endtask
endclass
module tb();
	top_if vif();
	apb_ral dut(vif.pclk, vif.presetn, vif.paddr, vif.pwdata, vif.psel, vif.pwrite, vif.penable, vif.prdata);

	initial begin
		vif.pclk=0;
	end

	always #10 vif.pclk = ~vif.pclk;

	initial begin
		uvm_config_db#(virtual top_if)::set(null,"*","vif", vif);
		run_test("test");
	end
endmodule
