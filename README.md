# NOC Verification Access Library (noc_vip)

可复用的 NOC 验证访问库，基于 SystemVerilog + UVM + Synopsys SVT VIP。

## 支持的协议

| 协议 | Adapter | Checker | SVT VIP |
|------|---------|---------|---------|
| AXI4 | noc_adapter_axi4 | noc_axi_checker | svt_axi_agent |
| AXI4-Lite | noc_adapter_axilite | noc_axi_checker | svt_axi_lite_agent |
| AHB-Lite | noc_adapter_ahblite | noc_ahb_checker | svt_ahb_agent |
| APB4 | noc_adapter_apb4 | noc_apb_checker | svt_apb_agent |
| Avalon-MM | noc_adapter_avalon_mm | - | svt_avalon_mm_agent |

## 快速开始

```systemverilog
import noc_pkg::*;

module test;
    initial begin
        noc_api_wrapper api = noc_api_wrapper::get();
        bit [1023:0] data;

        // 单次读写
        api.noc_write(.addr(64'hA000_0000), .data(1024'hDEAD_BEEF));
        api.noc_read(.addr(64'hA000_0000), .data(data));

        // Burst读写
        api.noc_burst_write(.addr(64'hA000_0000), .data(data_array), .len(15));
        api.noc_burst_read(.addr(64'hA000_0000), .data(data_array), .len(15));
    end
endmodule
```

## 目录结构

```
noc_vip/
├── CLAUDE.md              # 项目规范
├── config/                 # JSON配置文件
├── scripts/               # Python工具脚本
├── sv/                    # SystemVerilog源码
│   ├── adapter/           # 协议适配器
│   ├── agent/             # Agent (sequencer/driver/monitor)
│   ├── api/               # 统一API wrapper
│   ├── backdoor/          # 后门访问
│   ├── checker/           # 协议检查器
│   ├── coverage/          # 覆盖率模型
│   ├── env/               # Environment + Config
│   ├── error_injection/   # 错误注入
│   ├── logger/            # 事务日志
│   ├── performance/       # 性能监控
│   ├── sequence/          # Sequence + Virtual Sequence
│   ├── test/              # Test cases
│   ├── transaction/       # Transaction定义
│   └── virtual_sequencer/ # Virtual Sequencer
├── tb/                    # Testbench top + package
├── rtl/                   # DUT wrapper
├── sim/                   # 仿真脚本
├── logs/                  # 日志输出
└── reports/               # 报告输出
```

## 运行测试

```bash
# 编译
cd sim && make compile

# 运行冒烟测试
make run TEST=noc_smoke_test

# 运行全部回归
make regress

# 查看波形
make wave TEST=noc_burst_test

# 覆盖率
make coverage TEST=noc_random_traffic_test
```

## 自动生成测试

```bash
cd scripts

# 验证配置文件
python gen_slave_config.py --validate ../config/noc_slave_config.json

# 生成所有测试
python gen_noc_tests.py --config ../config/noc_slave_config.json --all

# 生成特定测试
python gen_noc_tests.py --config ../config/noc_slave_config.json --test legality

# 分析日志
python parse_logs.py --csv ../logs/noc_txn_log.csv --summary --perf-report
```

## 配置示例

参见 `config/noc_slave_config.json` — 描述 slaves 的地址空间、协议、burst能力、outstanding深度等。

## 约束覆盖

用户可通过继承 `noc_base_sequence` 并重写约束来实现自定义 traffic pattern：

```systemverilog
class my_custom_seq extends noc_base_sequence;
    constraint c_my_len  { burst_len inside {[3:7]}; }
    constraint c_my_size { data_size == 3; }
endclass
```

## 许可证

Internal use only.
