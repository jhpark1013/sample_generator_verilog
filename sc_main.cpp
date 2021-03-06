// -*- SystemC -*-
// DESCRIPTION: Verilator Example: Top level main for invoking SystemC model
//
// This file ONLY is placed under the Creative Commons Public Domain, for
// any use, without warranty, 2017 by Wilson Snyder.
// SPDX-License-Identifier: CC0-1.0
//======================================================================

// SystemC global header
#include <systemc.h>

// Include common routines
#include <verilated.h>
#if VM_TRACE
#include <verilated_vcd_sc.h>
#endif

#include <sys/stat.h>  // mkdir

// Include model header, generated from Verilating "top.v"
#include "Vtop.h"

int sc_main(int argc, char* argv[]) {
    // This is a more complicated example, please also see the simpler
    // examples/make_hello_c.

    // Prevent unused variable warnings
    if (0 && argc && argv) {}

    // Set debug level, 0 is off, 9 is highest presently used
    // May be overridden by commandArgs
    Verilated::debug(0);

    // Randomization reset policy
    // May be overridden by commandArgs
    Verilated::randReset(2);

    // Pass arguments so Verilated code can see them, e.g. $value$plusargs
    // This needs to be called before you create any model
    Verilated::commandArgs(argc, argv);

    // Create logs/ directory in case we have traces to put under it
    Verilated::mkdir("logs");

    // General logfile
    ios::sync_with_stdio();

    // Defaults time
#if (SYSTEMC_VERSION>20011000)
#else
    sc_time dut(1.0, sc_ns);
    sc_set_default_time_unit(dut);
#endif

    // Define clocks
#if (SYSTEMC_VERSION>=20070314)
    sc_clock clk     ("clk",    10,SC_NS, 0.5, 3,SC_NS, true);
    sc_clock fastclk ("fastclk", 2,SC_NS, 0.5, 2,SC_NS, true);
#else
    sc_clock clk     ("clk",    10, 0.5, 3, true);
    sc_clock fastclk ("fastclk", 2, 0.5, 2, true);
#endif

    // Define interconnect
    sc_signal<bool> reset_l;
    sc_signal<bool> En;
    sc_signal<vluint64_t> PacketSize;
    sc_signal<vluint64_t> PacketRate;
    // sc_signal<vluint64_t> PacketPattern;

    sc_signal<bool> M_AXIS_tvalid;
    sc_signal<bool> M_AXIS_tready;
    sc_signal<bool> M_AXIS_tlast;
    sc_signal<vluint64_t> M_AXIS_tdata;
    sc_signal<vluint64_t> in_quad;

    // Construct the Verilated model, from inside Vtop.h
    Vtop* top = new Vtop("top");
    // Attach signals to the model
    top->Clk       (clk);
    top->ResetN   (reset_l);
    // top->En (En);
    top->PacketSize (PacketSize);
    // top->PacketRate(PacketRate);
    // top->PacketPattern(PacketPattern);

    top->M_AXIS_tvalid  (M_AXIS_tvalid);
    top->M_AXIS_tready   (M_AXIS_tready);
    top->M_AXIS_tlast   (M_AXIS_tlast);
    top->M_AXIS_tdata (M_AXIS_tdata);
    // top->M_AXIS_tstrb (M_AXIS_tstrb);
    // top->M_AXIS_tkeep (M_AXIS_tkeep);
    // top->M_AXIS_tuser (M_AXIS_tuser);
    top->in_quad (in_quad);


#if VM_TRACE
    // Before any evaluation, need to know to calculate those signals only used
    //for tracing
    Verilated::traceEverOn(true);
#endif

    // You must do one evaluation before enabling waves, in order to allow
    // SystemC to interconnect everything for testing.
#if (SYSTEMC_VERSION>=20070314)
    sc_start(1,SC_NS);
#else
    sc_start(1);
#endif

#if VM_TRACE
    // If verilator was invoked with --trace argument,
    // and if at run time passed the +trace argument, turn on tracing
    VerilatedVcdSc* tfp = NULL;
    const char* flag = Verilated::commandArgsPlusMatch("trace");
    if (flag && 0==strcmp(flag, "+trace")) {
        cout << "Enabling waves into logs/vlt_dump.vcd...\n";
        tfp = new VerilatedVcdSc;
        top->trace(tfp, 99);  // Trace 99 levels of hierarchy
        Verilated::mkdir("logs");
        tfp->open("logs/vlt_dump.vcd");
    }
#endif

    // Simulate until $finish
    while (!Verilated::gotFinish()) {
#if VM_TRACE
        // Flush the wave files each cycle so we can immediately see the output
        // Don't do this in "real" programs, do it in an abort() handler instead
        if (tfp) tfp->flush();
#endif

        // Apply inputs
        if (VL_TIME_Q() > 1 && VL_TIME_Q() < 10) {
            reset_l = !1;  // Assert reset
        } else if (VL_TIME_Q() > 1) {
            reset_l = !0;  // Deassert reset
        }

        // Simulate 1ns
#if (SYSTEMC_VERSION>=20070314)
        sc_start(1,SC_NS);
#else
        sc_start(1);
#endif
    }

    // Final model cleanup
    top->final();

    // Close trace if opened
#if VM_TRACE
    if (tfp) { tfp->close(); tfp = NULL; }
#endif

    //  Coverage analysis (since test passed)
#if VM_COVERAGE
    Verilated::mkdir("logs");
    VerilatedCov::write("logs/coverage.dat");
#endif

    // Destroy model
    delete top; top = NULL;

    // Fin
    return 0;
}
