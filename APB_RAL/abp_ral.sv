module apb_ral(input pclk,
		input presetn,
		input[31:0] paddr,
		input[31:0] pwdata,
		input psel,
		input pwrite,
		input penable,
		output [31:0] prdata );

		reg[3:0] cntrl = 0;
		reg[31:0] reg1 = 0;
		reg[31:0] reg2 = 0;
		reg[31:0] reg3 = 0;
		reg[31:0] reg4 = 0;

		reg[31:0] rdata_tmp = 0;

		always @(posedge pclk) begin
			if(!presetn)begin
				cntrl <= 4'b0000;
				reg1 <= 32'b00000000;
				reg2 <= 32'b00000000;
				reg3 <= 32'b00000000;
				reg4 <= 32'b00000000;
				rdata_tmp <= 32'b00000000;
			end
		
			else if(psel && penable && pwrite)begin
				case(paddr)
					'h0 : cntrl <= pwdata;
					'h4 : reg1 <= pwdata;
					'h8 : reg2 <= pwdata;
					'hc : reg3 <= pwdata;
					'h10 : reg4 <= pwdata;
				endcase 
			end
			else if(psel && penable && !pwrite)begin
				case(paddr)
					'h0 : rdata_tmp <= {28'h0000000, cntrl};
					'h4 : rdata_tmp <= reg1;
					'h8 : rdata_tmp <= reg2;
					'hc : rdata_tmp <= reg3;
					'h10 : rdata_tmp <= reg4;
					default : rdata_tmp <= 32'h00000000;
				endcase
			end
		end
	assign prdata = rdata_tmp;
endmodule

interface top_if();
		logic pclk;
		logic presetn;
		logic[31:0] paddr;
		logic[31:0] pwdata;
		logic psel;
		logic pwrite;
		logic penable;
		logic[31:0] prdata;
endinterface
