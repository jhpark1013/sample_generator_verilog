module top
  (
   // Declare some signals so we can see how I/O works
   input         Clk,
   input         ResetN,

   // input wire En,
   output wire [39:0] PacketSize,
   // input wire [7:0] PacketRate,
   // input wire [31:0] PacketPattern,

   output wire  M_AXIS_tvalid,
   output wire  M_AXIS_tready,
   output wire M_AXIS_tlast,
  output wire [39:0] M_AXIS_tdata,

  // output wire [2:0] M_AXIS_tstrb,
  // output wire [2:0] M_AXIS_tkeep,
  // output wire M_AXIS_tuser,

//  input[1:0] in_small,
  input [39:0] in_quad
   );

   reg En;
   assign En = 1;

   assign PacketSize = in_quad + 'd8 ; //in_quad + 'hff;
   // assign M_AXIS_tdata = ~ResetN ? '0 : (in_quad + 40'b1);

   reg [39:0] counterR;
   // assign M_AXIS_tdata = counterR;
   always_ff @(posedge Clk)
     if(!ResetN)
       counterR <= 0;
   	else begin
       if(M_AXIS_tvalid && M_AXIS_tready)
         if(M_AXIS_tlast)
           counterR <= 0;
       	 else
           counterR<=counterR + 1;
     end

    always_ff @(posedge Clk)
      if(!ResetN)
        counterR <= 0;
      else begin
        counterR <= counterR + 1;
        if(counterR == 30)begin
          En = 0;
        end
      end

// fsm controls the state of the sample generator module.
// when En is 1 (slave defined), the module begins
// producing samples. when En is 0, the module waits.

reg enableSampleGenerationR;
wire enableSampleGenerationPosEdge;
wire enableSampleGenerationNegEdge;

assign enableSampleGenerationR = 1;

always @(posedge Clk)
  if(!ResetN) begin
    enableSampleGenerationR <= 0;
  end
  else begin
    enableSampleGenerationR <= enableSampleGenerationR;
  end

assign enableSampleGenerationPosEdge = En && (!enableSampleGenerationR);
assign enableSampleGenerationNegEdge = (!En) && enableSampleGenerationR;

`define FSM_STATE_IDLE  0
`define FSM_STATE_ACTIVE  1
`define FSM_STATE_WAIT_END 2

reg [1:0] fsm_currentState;
reg [1:0] fsm_prevState;

always_ff @(posedge Clk)
  if(!ResetN) begin
    fsm_currentState <= `FSM_STATE_IDLE;
    fsm_prevState <= `FSM_STATE_IDLE;
  end
  else begin

  case (fsm_currentState)

  `FSM_STATE_IDLE: begin
    if(enableSampleGenerationPosEdge) begin
      fsm_currentState <= `FSM_STATE_ACTIVE;
      fsm_prevState <= `FSM_STATE_IDLE;
    end
    else begin
      fsm_currentState <= `FSM_STATE_IDLE;
      fsm_prevState <= `FSM_STATE_IDLE;
    end
  end

  `FSM_STATE_ACTIVE: begin
    if(enableSampleGenerationNegEdge) begin
      fsm_currentState <= `FSM_STATE_WAIT_END;
      fsm_prevState <= `FSM_STATE_ACTIVE;
    end
    else begin
      fsm_currentState <= `FSM_STATE_ACTIVE;
      fsm_prevState <= `FSM_STATE_ACTIVE;
    end
  end

  `FSM_STATE_WAIT_END: begin
    if(lastDataIsBeingTransferred) begin
      fsm_currentState <= `FSM_STATE_IDLE;
      fsm_prevState <= `FSM_STATE_WAIT_END;
    end
    else begin
      fsm_currentState <= `FSM_STATE_WAIT_END;
      fsm_prevState <= `FSM_STATE_WAIT_END;
    end
  end

  default:begin
    fsm_currentState <= `FSM_STATE_IDLE;
    fsm_prevState <= `FSM_STATE_IDLE;
  end

  endcase
  end

// data transfer qualifiers
  reg 			dataIsBeingTransferred;
  reg 			lastDataIsBeingTransferred;

  assign dataIsBeingTransferred = M_AXIS_tvalid & M_AXIS_tready;
  assign lastDataIsBeingTransferred = dataIsBeingTransferred & M_AXIS_tlast;

// packet size
  reg 	[29:0]	packetSizeInDwords;
  reg 	[1:0]				validBytesInLastChunk;

  always_ff @(posedge Clk)
  	if ( ! ResetN ) begin
  		packetSizeInDwords <= 0;
  		validBytesInLastChunk <= 0;
  	end
  	else begin
      if ( enableSampleGenerationPosEdge ) begin
  			packetSizeInDwords <= 'd6 ; //PacketSize>> 2;
  			validBytesInLastChunk <= PacketSize - packetSizeInDwords * 4;
  		end
    end

// global counter is a 32 bit counter which counts up with every data transfer.
  reg [31:0] globalCounter;
  always_ff @(posedge Clk)
    if(!ResetN) begin
      globalCounter <= 0;
    end
    else begin
      if( dataIsBeingTransferred )
        globalCounter <= globalCounter + 1;
      else
        globalCounter <= globalCounter;
    end

  assign M_AXIS_tdata = globalCounter;

// packet counter counts how many dwords are being transferred for each packet.
  reg [29:0] packetCounter;
  always_ff @(posedge Clk)
    if(!ResetN) begin
      packetCounter <= 0;
    end
    else begin
      if(lastDataIsBeingTransferred) begin
        packetCounter <= 0 ;
      end
      else if(dataIsBeingTransferred) begin
        packetCounter <= packetCounter + 1;
      end
      else begin
        packetCounter <= packetCounter;
      end
    end


  // assign M_AXIS_tlast = 1'd0; //~ResetN ? '0 : 0'b1;
  assign M_AXIS_tvalid = 'd1; //~ResetN ? '0 :  1'b1;
  assign M_AXIS_tready = 1'd1; //~ResetN ? '0 : 1'b1;
  // assign M_AXIS_tdata = ~ResetN ? '0 : (in_quad + 40'b1);

// TVALID generated when fsm is in active state. then generate packets.
  // assign M_AXIS_tvalid = ((fsm_currentState == `FSM_STATE_ACTIVE) ||
  //   (fsm_currentState == `FSM_STATE_WAIT_END)) ? 1 : 0;
// TLAST
  assign M_AXIS_tlast = (packetCounter == 6) ? 1 : 0;
  // assign M_AXIS_tlast = (validBytesInLastChunk == 0) ?
  // ( (packetCounter == (packetSizeInDwords-1)) ? 1 : 0 ) :
  // ( (packetCounter == packetSizeInDwords   )  ? 1 : 0 );
// TSTRB
//   assign M_AXIS_tstrb =
//   ( (!lastDataIsBeingTransferred) && dataIsBeingTransferred) ? 4'hf :
//     (lastDataIsBeingTransferred && (validBytesInLastChunk==3) ) ? 4'h7 :
//     (lastDataIsBeingTransferred && (validBytesInLastChunk==2) ) ? 4'h3 :
//     (lastDataIsBeingTransferred && (validBytesInLastChunk==1) ) ? 4'h1 : 4'hf;
//
// // TKEEP and M_AXIS_TUSER
// assign M_AXIS_tkeep = M_AXIS_tstrb; // 4'hf
// assign M_AXIS_tuser = 0;

endmodule
