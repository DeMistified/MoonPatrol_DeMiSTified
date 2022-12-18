set_clock_groups -asynchronous -group spiclk -group [get_clocks ${topmodule}pll|altpll_component|auto_generated|pll1|clk[0]]
set_clock_groups -asynchronous -group spiclk -group [get_clocks ${topmodule}pll|altpll_component|auto_generated|pll1|clk[1]]
set_clock_groups -asynchronous -group [get_clocks ${topmodule}pll|altpll_component|auto_generated|pll1|clk[0]] -group [get_clocks ${topmodule}pll|altpll_component|auto_generated|pll1|clk[2]]

set_false_path -to ${VGA_OUT}

set_false_path -to ${FALSE_OUT}
set_false_path -from ${FALSE_IN}
