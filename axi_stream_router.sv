`include "config_router.svh"

module axi_stream_router (
    input  logic         clk,
    input  logic         rst,

    // AXI-Stream input
    input  logic         s_tvalid,
    input  logic [21:0]   s_tdata,
    output logic         s_tready,

    // Config input
    input  logic         config_tvalid,
    input  logic [$bits(config_t)-1:0] config_tdata,
    output logic         config_tready,

    // AXI-Stream output 0
    output logic         m0_tvalid,
    output logic [21:0]   m0_tdata,
    input  logic         m0_tready,

    // AXI-Stream output 1
    output logic         m1_tvalid,
    output logic [21:0]   m1_tdata,
    input  logic         m1_tready,

    // AXI-Stream output 2
    output logic         m2_tvalid,
    output logic [21:0]   m2_tdata,
    input  logic         m2_tready
);

    typedef enum logic [2:0] {
        IDLE, CONFIG_READ, ROUTE_M0, ROUTE_M1, ROUTE_M2, DONE
    } state_t;

    state_t pre_state, next_state;

    config_t config_struct;

   // logic [1:0] config_idx;
    //logic       config_done;
    logic [7:0] config_data[0:2]; // [0]=MSB, [2]=LSB

    logic [7:0] count0, count1, count2;
    
    logic flag;
    
    // FSM state register
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            pre_state <= IDLE;
        else
            pre_state <= next_state;
    end

    // FSM next state logic
    always_comb begin
    //    next_state = pre_state;
        case (pre_state)
            IDLE:
                next_state = CONFIG_READ;

            CONFIG_READ:
//                next_state = (config_tvalid && config_tready) ? ROUTE_M0 : CONFIG_READ;
                    if(config_tvalid && config_tready) next_state = ROUTE_M0;
                    else next_state = CONFIG_READ;
            ROUTE_M0:
                next_state = ((count0 == config_struct.port0_count) && m0_tvalid && m0_tready) ? ROUTE_M1 : ROUTE_M0;

            ROUTE_M1:
                next_state = ((count1 == config_struct.port1_count) && m1_tvalid && m1_tready) ? ROUTE_M2 : ROUTE_M1;

            ROUTE_M2:
                next_state = ((count2 == config_struct.port2_count) && m2_tvalid && m2_tready) ? DONE : ROUTE_M2;

            DONE:
                next_state = IDLE;

            default:
                next_state = IDLE;
        endcase
    end

    // Output data
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            m0_tdata <= 0;
            m1_tdata <= 0;
            m2_tdata <= 0;
            m0_tvalid<=0;
            m1_tvalid<=0;
            m2_tvalid<=0;
            count0 <= 0;
            count1 <= 0;
            count2 <= 0;
            config_struct<=0;
        end else  begin
            case (pre_state)
                IDLE: begin
                   m0_tdata <= 0;
                   m1_tdata <= 0;
                   m2_tdata <= 0;
                   m0_tvalid<=0;
                   m1_tvalid<=0;
                   m2_tvalid<=0;
                   count0 <= 0;
                   count1 <= 0;
                   count2 <= 0;
                   flag <= 0;
                  // config_struct<=0;
                end
                CONFIG_READ: begin
//                 if(config_tvalid && config_tready)begin
                     config_struct<=config_tdata;
//                    flag <= 1;
//                     end
//                  else begin
//                     config_struct<=config_struct;
//                    flag <= 0;
//                    end
                  end
                     
                ROUTE_M0: begin
                    m1_tvalid<=0;
                    m2_tvalid<=0;
                    if(s_tvalid && s_tready && m0_tready) begin   
                        m0_tdata <= s_tdata;
                        m0_tvalid <= s_tvalid;
                        count0 <= count0+1'b1;
                    end
                    else begin
                        m0_tdata <=  m0_tdata;
                        m0_tvalid <= 1'b0;
                       count0 <= count0;
                    end
                end 
                ROUTE_M1: begin
                    m0_tvalid<=0;
                    m2_tvalid<=0;
                 if(s_tvalid && s_tready && m1_tready) begin
                        m1_tdata <= s_tdata;
                        m1_tvalid <= s_tvalid;
                        count1 <= count1+1'b1;
                    end
                    else begin
                        m1_tdata <=  m1_tdata;
                        m1_tvalid <= 1'b0;
                        count1 <= count1;
                    end
                  end
                ROUTE_M2: begin
                   m0_tvalid<=0;
                    m1_tvalid<=0;
                    if(s_tvalid && s_tready && m2_tready) begin
                        m2_tdata <= s_tdata;
                        m2_tvalid <= s_tvalid;
                       count2 <= count2+1'b1;
                    end
                    else begin
                        m2_tdata <=  m2_tdata;
                        m2_tvalid <= 1'b0;
                       count2 <= count2;
                    end
                end 
                DONE: begin
                   m0_tdata <= 0;
                   m1_tdata <= 0;
                   m2_tdata <= 0;
                   m0_tvalid<=0;
                   m1_tvalid<=0;
                   m2_tvalid<=0;
                end
           default: begin
                    m0_tdata <= 0;
                    m1_tdata <= 0;
                    m2_tdata <= 0;
                end
            
            endcase
        end
    end

    // Handshaking
    always_comb begin
            case(pre_state)
                IDLE: begin
                    s_tready = 1'b0;
                    config_tready = 1'b0;
                end
                CONFIG_READ: begin
                    s_tready = 1'b0;
                    config_tready = 1'b1;
                end
                ROUTE_M0: begin
                    s_tready = 1'b1;
                    config_tready = 1'b0;
                end 
                ROUTE_M1: begin
                    s_tready = 1'b1;
                    config_tready = 1'b0;
                end
                ROUTE_M2: begin
                    s_tready = 1'b1;
                    config_tready = 1'b0;
                end 
                DONE: begin
                    s_tready = 1'b0;
                    config_tready = 1'b0;
                end
           default: begin
                    s_tready = 1'b0;
                    config_tready = 1'b0;
                end  
           endcase
    end

endmodule
