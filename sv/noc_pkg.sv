// noc_pkg.sv - NOC Verification Access Library Package
package noc_pkg;

    `include "uvm_macros.svh"
    import uvm_pkg::*;

    // Macros
    `include "noc_macros.svh"

    // Transaction
    `include "transaction/noc_unified_transaction.sv"
    `include "transaction/noc_txn_record.sv"

    // Config
    `include "env/noc_slave_config.sv"
    `include "env/noc_master_config.sv"
    `include "env/noc_env_cfg.sv"

    // Adapter
    `include "adapter/noc_adapter_base.sv"
    `include "adapter/noc_adapter_axi4.sv"
    `include "adapter/noc_adapter_axilite.sv"
    `include "adapter/noc_adapter_ahblite.sv"
    `include "adapter/noc_adapter_apb4.sv"
    `include "adapter/noc_adapter_avalon_mm.sv"

    // Agent
    `include "agent/noc_unified_sequencer.sv"
    `include "agent/noc_unified_driver.sv"
    `include "agent/noc_unified_monitor.sv"
    `include "agent/noc_unified_agent.sv"

    // Virtual Sequencer
    `include "virtual_sequencer/noc_virtual_sequencer.sv"

    // Env
    `include "env/noc_env.sv"

    // Checker
    `include "checker/noc_violation_report.sv"
    `include "checker/noc_protocol_checker.sv"
    `include "checker/noc_axi_checker.sv"
    `include "checker/noc_ahb_checker.sv"
    `include "checker/noc_apb_checker.sv"

    // Logger
    `include "logger/noc_txn_logger.sv"

    // Coverage
    `include "coverage/noc_coverage_collector.sv"

    // Performance
    `include "performance/noc_perf_sample.sv"
    `include "performance/noc_perf_monitor.sv"

    // Error Injection
    `include "error_injection/noc_error_injector.sv"

    // Backdoor
    `include "backdoor/noc_backdoor_access.sv"

    // Scoreboard
    `include "noc_scoreboard.sv"

    // API
    `include "api/noc_api_wrapper.sv"

    // Sequences
    `include "sequence/noc_base_sequence.sv"
    `include "sequence/noc_read_sequence.sv"
    `include "sequence/noc_virtual_sequence_base.sv"

    // Tests
    `include "test/noc_test_base.sv"

endpackage
