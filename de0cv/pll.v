module pll (
		input  wire  inclk0,   
		output wire  c0, 
		output wire  c1, 
		output wire  c2, 
		output wire  locked    
	);

	altera_pll #(
		.fractional_vco_multiplier("false"),
		.reference_clock_frequency("50.0 MHz"),
		.operation_mode("direct"),
		.number_of_clocks(3),
		.output_clock_frequency0("30.000000 MHz"),
		.phase_shift0("0 ps"),
		.duty_cycle0(50),
		.output_clock_frequency1("48.000000 MHz"),
		.phase_shift1("0 ps"),
		.duty_cycle1(50),
		.output_clock_frequency2("3.582089 MHz"),
		.phase_shift2("0 ps"),
		.duty_cycle2(50),
		.pll_type("General"),
		.pll_subtype("General")
	) altera_pll_i (
		.outclk	({c2, c1, c0}),
		.locked	(locked),
		.fboutclk	( ),
		.fbclk	(1'b0),
		.refclk	(inclk0)
	);


endmodule

