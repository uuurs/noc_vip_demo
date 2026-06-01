// noc_read_sequence.sv - Single read sequence
class noc_read_sequence extends noc_base_sequence;

    `uvm_object_utils(noc_read_sequence)

    function new(string name = "noc_read_sequence");
        super.new(name);
        target_direction = noc_unified_transaction::NOC_READ;
        burst_len = 8'h0;
    endfunction

    constraint c_read_only {
        target_direction == noc_unified_transaction::NOC_READ;
        burst_len == 0;
    }
endclass

// noc_write_sequence.sv - Single write sequence
class noc_write_sequence extends noc_base_sequence;

    `uvm_object_utils(noc_write_sequence)

    rand bit [127:0] wstrb_val;

    function new(string name = "noc_write_sequence");
        super.new(name);
        target_direction = noc_unified_transaction::NOC_WRITE;
        burst_len = 8'h0;
        wstrb_val = 128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
    endfunction

    constraint c_write_only {
        target_direction == noc_unified_transaction::NOC_WRITE;
        burst_len == 0;
    }

    task body();
        noc_unified_transaction txn;
        `uvm_do_with(txn, {
            addr      == target_addr;
            direction == target_direction;
            burst     == target_burst;
            len       == burst_len;
            size      == data_size;
            id        == txn_id;
            wstrb     == wstrb_val;
        })
    endtask
endclass

// noc_burst_read_sequence.sv - Burst read sequence
class noc_burst_read_sequence extends noc_base_sequence;

    `uvm_object_utils(noc_burst_read_sequence)

    function new(string name = "noc_burst_read_sequence");
        super.new(name);
        target_direction = noc_unified_transaction::NOC_READ;
    endfunction

    constraint c_burst_read {
        target_direction == noc_unified_transaction::NOC_READ;
        burst_len inside {[1:15]};
    }

    constraint c_valid_burst_type {
        target_burst inside {noc_unified_transaction::INCR, noc_unified_transaction::WRAP};
    }
endclass

// noc_burst_write_sequence.sv - Burst write sequence
class noc_burst_write_sequence extends noc_base_sequence;

    `uvm_object_utils(noc_burst_write_sequence)

    rand bit [127:0] wstrb_val;

    function new(string name = "noc_burst_write_sequence");
        super.new(name);
        target_direction = noc_unified_transaction::NOC_WRITE;
        wstrb_val = 128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
    endfunction

    constraint c_burst_write {
        target_direction == noc_unified_transaction::NOC_WRITE;
        burst_len inside {[1:15]};
    }

    task body();
        noc_unified_transaction txn;
        `uvm_do_with(txn, {
            addr      == target_addr;
            direction == target_direction;
            burst     == target_burst;
            len       == burst_len;
            size      == data_size;
            id        == txn_id;
            wstrb     == wstrb_val;
        })
    endtask
endclass

// noc_random_traffic_sequence.sv - Random traffic generator
class noc_random_traffic_sequence extends noc_base_sequence;

    `uvm_object_utils(noc_random_traffic_sequence)

    int m_num_txns;
    int m_txn_count;

    function new(string name = "noc_random_traffic_sequence");
        super.new(name);
        m_num_txns = 100;
        m_txn_count = 0;
    endfunction

    task body();
        for (int i = 0; i < m_num_txns; i++) begin
            if (!randomize()) begin
                `uvm_error("NOC_SEQ", "Randomization failed")
                continue;
            end
            super.body();
            m_txn_count++;
        end
        `uvm_info("NOC_SEQ", $sformatf("Generated %0d random transactions", m_txn_count), UVM_LOW)
    endtask
endclass

// noc_error_injection_sequence.sv - Error injection sequence
class noc_error_injection_sequence extends noc_base_sequence;

    `uvm_object_utils(noc_error_injection_sequence)

    noc_error_injector m_injector;
    int m_num_errors;

    function new(string name = "noc_error_injection_sequence");
        super.new(name);
        m_num_errors = 10;
    endfunction

    task body();
        for (int i = 0; i < m_num_errors; i++) begin
            noc_unified_transaction txn;
            `uvm_do_with(txn, {
                addr      == target_addr;
                direction == target_direction;
                burst     == target_burst;
                len       == burst_len;
                size      == data_size;
            })
            if (m_injector != null)
                m_injector.inject(txn);
            `uvm_info("NOC_SEQ", $sformatf("Error injection txn: %s", txn.convert2string()), UVM_MEDIUM)
        end
    endtask
endclass
