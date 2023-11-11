module async_fifo #(parameter DATA_WIDTH=8, DEPTH=8)(input rst_n, wr, rd,input [(DATA_WIDTH-1):0] din,
		  output reg empty, almost_empty, full, almost_full, wr_err, rd_err, wr_ack, rd_ack,
		  output reg [(DATA_WIDTH-1):0] dout);
	
	reg [($clog2(DEPTH)):0]ptr=0;
	reg [(DATA_WIDTH-1) :0] memory[(DEPTH-1):0];
	reg fifo_full=0; reg fifo_empty=1;	

	always @(rst_n or wr or rd)begin
		if(!rst_n)begin
			no_ack(); no_err(); ptr=0; dout='dz; flag();
		end
		else begin
		    if(wr &&(!rd))begin
			//Write onditions 1.FIFO FULL & FIFO NOT FULL
			if(!(fifo_full))begin
				memory[ptr]=din; ptr=ptr+1; 
				write_ack(); flag();	
			end
			else begin
				write_err(); flag(); 
			end
		    end
		    if((!wr) && rd)begin
			if(!fifo_empty)begin
				dout = memory[0]; shift(); ptr=ptr-1; read_ack(); flag();
			end
			else begin
				read_err(); flag();
			end
		    end
		else begin
			no_ack(); no_err(); flag();
		   end
		end
	end

	function void write_ack();
		wr_ack=1; rd_ack=0;
		wr_err=0; rd_err=0;
	endfunction

	function void read_ack();
		wr_ack=0; rd_ack=1;
		wr_err=0; rd_err=0;
	endfunction

	function void write_err();
		wr_ack=0; rd_ack=0;
		wr_err=1; rd_err=0;
	endfunction

	function void read_err();
		wr_ack=0; rd_ack=0;
		wr_err=0; rd_err=1;
	endfunction

	function void no_ack();
		wr_ack=0; rd_ack=0;
		//wr_err=0; rd_err=0;
	endfunction

	function void no_err();
		//wr_ack=1; rd_ack=0;
		wr_err=0; rd_err=0;
	endfunction

	function void shift();
		memory[0] = memory[1];
		memory[1] = memory[2];
		memory[2] = memory[3];
		memory[3] = memory[4];
		memory[4] = memory[5];
		memory[5] = memory[6];
		memory[6] = memory[7];
		memory[7] = memory[7];
	endfunction

	function void flag();
		case(ptr)
			(DEPTH - DEPTH) : begin
				empty=1; almost_empty=0; almost_full=0; full=0;
				fifo_empty=1; fifo_full=0;
			    end

			(DEPTH - DEPTH + 1) : begin
				empty=0; almost_empty=1; almost_full=0; full=0;
				fifo_empty=0; fifo_full=0;
			    end

			(DEPTH - 1) : begin
				empty=0; almost_empty=0; almost_full=1; full=0;
				fifo_empty=0; fifo_full=0;
			    end

			(DEPTH) : begin
				empty=0; almost_empty=0; almost_full=0; full=1;
				fifo_empty=0; fifo_full=1;
			    end

			default : begin

				end
		endcase
	endfunction


endmodule
