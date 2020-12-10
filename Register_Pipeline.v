
//# Register Pipeline

// Pipelines data words through a number of register stages, with both
// parallel and serial inputs and outputs. Besides the obvious uses for
// serial/parallel conversion and pipeline alignment, a register pipeline can
// be part of shift-and-add algorithms such as multiplication through
// conditional addition.

// Each cycle `clock_enable` is high, the pipeline shifts by one from LSB to
// MSB, or loads a new set of parallel values. **Load overrides shift**.
// `pipe_in` feeds the LSB, and `pipe_out` read from the MSB.

// **NOTE**: `PIPE_DEPTH` must be 1 or greater.  (*Supporting a depth of zero
// would make this code far too messy and leave the parallel input/output
// ports unconnected, which will raise CAD warnings. See the [Simple Register
// Pipeline](./Register_Pipeline_Simple.html) instead.*)

// Depending on how you parameterize and use it, a register pipeline can act
// as a delay pipeline or a shift register:

// * For a delay pipeline, set `WORD_WIDTH` to the width of the data word, then
// `PIPE_DEPTH` to the number of delay stages. This will move whole data words
// along the pipeline. 
// * For a shift register, set `WORD_WIDTH` to 1, and `PIPE_DEPTH` to the
// width of the data word you wish to shift in or out bit-by-bit. Load the
// word via `parallel_in`, then shift it out through `pipe_out`. Or, shift in
// `PIPE_DEPTH` bits through `pipe_in`, then read the data word on
// `parallel_out`.

// If no parallel loads are required, hardwire `parallel_load` to zero, and
// the multiplexers will optimize away, if any, and you'll end up with a pure
// shift register (but see the [Simple Register
// Pipeline](./Register_Pipeline_Simple.html) if this is your main use-case).
// Conversely, hardwire `parallel_load` to one, and tie off the `pipe_in`
// input, and you'll end up with a conveniently packaged bank of registers.

// The `RESET_VALUES` parameter allows each pipeline stage to start loaded
// with a known initial value, which can simplify system startup. The pipeline
// will also clear to the same values. Set `RESET_VALUES` to the concatenation
// of all initial/reset values, with the rightmost value being the first one
// (at the least-significant bit (LSB)).


`default_nettype none

module Register_Pipeline
#(
    parameter                   WORD_WIDTH      = 0,
    parameter                   PIPE_DEPTH      = 0,
    // Don't set at instantiation
    parameter                   TOTAL_WIDTH     = WORD_WIDTH * PIPE_DEPTH,

    // concatenation of each stage initial/reset value
    parameter [TOTAL_WIDTH-1:0] RESET_VALUES    = 0
)
(
    input   wire                        clock,
    input   wire                        clock_enable,
    input   wire                        clear,
    input   wire                        parallel_load,
    input   wire    [TOTAL_WIDTH-1:0]   parallel_in,
    output  reg     [TOTAL_WIDTH-1:0]   parallel_out,
    input   wire    [WORD_WIDTH-1:0]    pipe_in,
    output  reg     [WORD_WIDTH-1:0]    pipe_out
);

    localparam WORD_ZERO = {WORD_WIDTH{1'b0}};

    initial begin
        pipe_out = WORD_ZERO;
    end

// Each pipeline state is composed of a Multiplexer feeding a Register, so we
// can select either the output of the previous Register, or the parallel load
// data. So we need a set of input and ouput wires for each stage. 

    wire [WORD_WIDTH-1:0] pipe_stage_in     [PIPE_DEPTH-1:0];
    wire [WORD_WIDTH-1:0] pipe_stage_out    [PIPE_DEPTH-1:0];

// The following attributes prevent the implementation of the multiplexer with
// DSP blocks. This can be a useful implementation choice sometimes, but here
// it's terrible, since FPGA flip-flops usually have separate data and
// synchronous load inputs, giving us a 2:1 mux for free. If not, then we
// should use LUTs instead, or other multiplexers built into the logic blocks.

    (* multstyle = "logic" *) // Quartus
    (* use_dsp   = "no" *)    // Vivado

// We strip out first iteration of module instantiations to avoid having to
// refer to index -1 in the generate loop, and also to connect to `pipe_in`
// rather than the output of a previous register.

    Multiplexer_Binary_Behavioural
    #(
        .WORD_WIDTH     (WORD_WIDTH),
        .ADDR_WIDTH     (1),
        .INPUT_COUNT    (2)
    )
    pipe_input_select
    (
        .selector       (parallel_load),    
        .words_in       ({parallel_in[0 +: WORD_WIDTH], pipe_in}),
        .word_out       (pipe_stage_in[0])
    );

    Register
    #(
        .WORD_WIDTH     (WORD_WIDTH),
        .RESET_VALUE    (RESET_VALUES[0 +: WORD_WIDTH])
    )
    pipe_stage
    (
        .clock          (clock),
        .clock_enable   (clock_enable),
        .clear          (clear),
        .data_in        (pipe_stage_in[0]),
        .data_out       (pipe_stage_out[0])
    );

    always @(*) begin
        parallel_out[0 +: WORD_WIDTH] = pipe_stage_out[0];
    end

// Now repeat over the remainder of the pipeline stages, starting at stage 1,
// connecting each pipeline stage to the output of the previous pipeline
// stage.

    generate

        genvar i;

        for(i=1; i < PIPE_DEPTH; i=i+1) begin : pipe_stages

            (* multstyle = "logic" *) // Quartus
            (* use_dsp   = "no" *)    // Vivado

            Multiplexer_Binary_Behavioural
            #(
                .WORD_WIDTH     (WORD_WIDTH),
                .ADDR_WIDTH     (1),
                .INPUT_COUNT    (2)
            )
            pipe_input_select
            (
                .selector       (parallel_load),    
                .words_in       ({parallel_in[WORD_WIDTH*i +: WORD_WIDTH], pipe_stage_out[i-1]}),
                .word_out       (pipe_stage_in[i])
            );


            Register
            #(
                .WORD_WIDTH     (WORD_WIDTH),
                .RESET_VALUE    (RESET_VALUES[WORD_WIDTH*i +: WORD_WIDTH])
            )
            pipe_stage
            (
                .clock          (clock),
                .clock_enable   (clock_enable),
                .clear          (clear),
                .data_in        (pipe_stage_in[i]),
                .data_out       (pipe_stage_out[i])
            );

            always @(*) begin
                parallel_out[WORD_WIDTH*i +: WORD_WIDTH] = pipe_stage_out[i];
            end

        end

    endgenerate

// And finally, connect the output of the last register to the module pipe output.

    always @(*) begin
        pipe_out = pipe_stage_out[PIPE_DEPTH-1];
    end

endmodule

