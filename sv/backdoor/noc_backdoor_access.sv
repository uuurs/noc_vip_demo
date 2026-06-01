// noc_backdoor_access.sv - Backdoor access (RAL, HDL, Memory paths)
class noc_backdoor_access extends uvm_component;

    `uvm_component_utils(noc_backdoor_access)

    typedef enum bit [1:0] {
        BACKDOOR_RAL = `NOC_BACKDOOR_RAL,
        BACKDOOR_HDL = `NOC_BACKDOOR_HDL,
        BACKDOOR_MEM = `NOC_BACKDOOR_MEM
    } backdoor_type_e;

    noc_env_cfg     m_cfg;

    // RAL model
    uvm_reg_block   m_ral_model;

    // HDL backdoor path mapping
    string          m_hdl_path_map[bit [63:0]];  // addr -> HDL path

    // Memory backdoor (associative array)
    bit [7:0]       m_memory[bit [63:0]];

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(noc_env_cfg)::get(this, "", "noc_env_cfg", m_cfg))
            `uvm_fatal("NOC_BACKDOOR", "Failed to get noc_env_cfg from config_db")
    endfunction

    // =====================================================
    // UVM RAL Backdoor
    // =====================================================
    function void set_ral_model(uvm_reg_block ral);
        m_ral_model = ral;
    endfunction

    task ral_backdoor_read(bit [63:0] addr, output bit [31:0] data);
        if (m_ral_model == null) begin
            `uvm_error("NOC_BACKDOOR", "RAL model not set")
            return;
        end
        // Finds register at addr and does backdoor peek
        uvm_reg regs[$];
        m_ral_model.get_registers(regs);
        foreach (regs[i]) begin
            if (regs[i].get_address() == addr) begin
                regs[i].peek(.status(, .value(data), .check(UVM_CHECK),
                    .path(UVM_BACKDOOR), .map(, .parent(this)));
                `uvm_info("NOC_BACKDOOR", $sformatf("RAL BD read: 0x%0h = 0x%0h", addr, data), UVM_MEDIUM)
                return;
            end
        end
        `uvm_warning("NOC_BACKDOOR", $sformatf("RAL BD: No register at 0x%0h", addr))
    endtask

    task ral_backdoor_write(bit [63:0] addr, bit [31:0] data);
        if (m_ral_model == null) begin
            `uvm_error("NOC_BACKDOOR", "RAL model not set")
            return;
        end
        uvm_reg regs[$];
        m_ral_model.get_registers(regs);
        foreach (regs[i]) begin
            if (regs[i].get_address() == addr) begin
                regs[i].poke(.status(, .value(data), .check(UVM_CHECK),
                    .path(UVM_BACKDOOR), .map(, .parent(this)));
                `uvm_info("NOC_BACKDOOR", $sformatf("RAL BD write: 0x%0h = 0x%0h", addr, data), UVM_MEDIUM)
                return;
            end
        end
        `uvm_warning("NOC_BACKDOOR", $sformatf("RAL BD: No register at 0x%0h", addr))
    endtask

    // =====================================================
    // HDL Backdoor
    // =====================================================
    function void register_hdl_path(bit [63:0] addr, string hdl_path);
        m_hdl_path_map[addr] = hdl_path;
    endfunction

    task hdl_backdoor_read(string hdl_path, output bit [31:0] data);
        if (!$value$plusargs("HDL_BACKDOOR_EN=1", data)) begin
            `uvm_info("NOC_BACKDOOR", $sformatf("HDL BD read: %s", hdl_path), UVM_HIGH)
            // In real implementation, uses $hdl_xmr or DPI
            // data = hdl_path;
        end
    endtask

    task hdl_backdoor_write(string hdl_path, bit [31:0] data);
        `uvm_info("NOC_BACKDOOR", $sformatf("HDL BD write: %s = 0x%0h", hdl_path, data), UVM_HIGH)
        // In real implementation, uses $hdl_xmr or DPI
    endtask

    // =====================================================
    // Memory Backdoor
    // =====================================================
    task mem_backdoor_read(bit [63:0] addr, output bit [7:0] data);
        if (m_memory.exists(addr)) begin
            data = m_memory[addr];
        end else begin
            data = 8'h00;
            `uvm_info("NOC_BACKDOOR", $sformatf("MEM BD read miss: 0x%0h", addr), UVM_HIGH)
        end
    endtask

    task mem_backdoor_write(bit [63:0] addr, bit [7:0] data);
        m_memory[addr] = data;
        `uvm_info("NOC_BACKDOOR", $sformatf("MEM BD write: 0x%0h = 0x%0h", addr, data), UVM_HIGH)
    endtask

    task mem_backdoor_burst_read(
        bit [63:0] addr, output bit [7:0] data[], input int len
    );
        data = new[len];
        for (int i = 0; i < len; i++) begin
            mem_backdoor_read(addr + i, data[i]);
        end
    endtask

    task mem_backdoor_burst_write(
        bit [63:0] addr, bit [7:0] data[], input int len
    );
        for (int i = 0; i < len; i++) begin
            mem_backdoor_write(addr + i, data[i]);
        end
    endtask

    // =====================================================
    // Unified Backdoor API
    // =====================================================
    task backdoor_read(
        backdoor_type_e bd_type, bit [63:0] addr,
        output bit [31:0] data, string hdl_path = ""
    );
        case (bd_type)
            BACKDOOR_RAL: ral_backdoor_read(addr, data);
            BACKDOOR_HDL: hdl_backdoor_read(hdl_path, data);
            BACKDOOR_MEM: begin
                bit [7:0] byte_data;
                mem_backdoor_read(addr, byte_data);
                data = {24'h0, byte_data};
            end
        endcase
    endtask

    task backdoor_write(
        backdoor_type_e bd_type, bit [63:0] addr,
        bit [31:0] data, string hdl_path = ""
    );
        case (bd_type)
            BACKDOOR_RAL: ral_backdoor_write(addr, data);
            BACKDOOR_HDL: hdl_backdoor_write(hdl_path, data);
            BACKDOOR_MEM: mem_backdoor_write(addr, data[7:0]);
        endcase
    endtask

    // Compare front-door vs back-door data
    function bit compare_fd_bd(bit [63:0] fd_data, bit [63:0] bd_data, string context = "");
        if (fd_data !== bd_data) begin
            `uvm_error("NOC_BACKDOOR", $sformatf(
                "%s FD/BD mismatch: FD=0x%0h BD=0x%0h", context, fd_data, bd_data))
            return 1'b0;
        end
        return 1'b1;
    endfunction
endclass
