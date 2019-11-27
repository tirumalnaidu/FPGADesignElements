
//# Binary Demultiplexer

// Connects the `word_in` input port to one of the words in the `words_out`
// output port, as selected by the `output_port_selector` binary address, and
// raises the corresponding valid bit in the `valids_out` output port.  If the
// `output_port_selector` value is greater than the number of output words
// specified by the `OUTPUT_COUNT` parameter, then none of the `valids_out`
// bits will be set.

//## Implementation Options

// Set the `BROADCAST` parameter to 1 to simply replicate and connect
// `word_in` to each word in `words_out`, without any logic. The valid bit
// will indicate which downstream logic should accept the data, and other
// logic can snoop the data if that's part of your larger design.

// Set the `BROADCAST` parameter to 0 to send `word_in` to *only* the selected
// word in `words_out`, whose valid bit is set. All other output words are
// annulled to zero. If no valid bit is set, all output words stay at zero.

// Not broadcasting the input to the output costs some logic, but less than it
// appears from a standalone synthesis of the demultiplexer: the inferred
// [Annullers](./Annuller.html) will very likely disappear into downstream LUT
// logic, it also makes tracing a simulation easier, and adds some design
// security and robustness since unselected downstream logic cannot snoop or
// accidentally receive other data.

// Setting `BROADCAST` to any value other than 1 or 0 will disconnect
// `word_in` from `words_out`, raise some critical warnings in your CAD tool,
// and generally cause a lot of downstream logic to optimize away, so you
// should notice...

module Demultiplexer_Binary
#(
    parameter       BROADCAST           = 0,
    parameter       WORD_WIDTH          = 0,
    parameter       ADDR_WIDTH          = 0,
    parameter       OUTPUT_COUNT        = 0,

    // Do not set at instantiation
    parameter   TOTAL_WIDTH = WORD_WIDTH * OUTPUT_COUNT
)
(
    input   wire    [ADDR_WIDTH-1:0]    output_port_selector,
    input   wire    [WORD_WIDTH-1:0]    word_in,
    output  wire    [TOTAL_WIDTH-1:0]   words_out,
    output  wire    [OUTPUT_COUNT-1:0]  valids_out
);

// Convert the binary `output_port_selector` to a single one-hot bit vector
// which signals which output port will receive the input word.

    Binary_to_One_Hot
    #(
        .BINARY_WIDTH   (ADDR_WIDTH),
        .OUTPUT_WIDTH   (OUTPUT_COUNT)
    )
    valid_out
    (
        .binary_in      (output_port_selector),
        .one_hot_out    (valids_out)
    );

// If we are *not* broadcasting, then for each output port, annul the output
// if its valid bit is not set.  Thus, only the selected output port will have
// the `word_in` data. All others will stay at zero.  Otherwise, simply
// replicate and connect the input to all outputs. [This is one of the very
// rare cases where you must use the `assign`
// statement.](./verilog.html#assign)

    generate
        if (BROADCAST == 0) begin
            genvar i;
            for (i=0; i < OUTPUT_COUNT; i=i+1) begin: per_output
                Annuller
                #(
                    .WORD_WIDTH     (WORD_WIDTH),
                    .IMPLEMENTATION ("AND")
                )
                output_gate
                (
                    .annul          ((valids_out[i] == 1'b0)),
                    .data_in        (word_in),
                    .data_out       (words_out[WORD_WIDTH*i +: WORD_WIDTH])
                );
            end
        end
        else
        if (BROADCAST == 1) begin
            assign words_out = {OUTPUT_COUNT{word_in}};
        end
    endgenerate

endmodule

