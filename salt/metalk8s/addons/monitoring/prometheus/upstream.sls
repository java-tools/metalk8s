#!jinja | kubernetes kubeconfig=/etc/kubernetes/admin.conf&context=kubernetes-admin@kubernetes

{%- from "metalk8s/repo/macro.sls" import build_image_name with context %}

# The content below has been generated from
# https://github.com/coreos/prometheus-operator, v0.24.0 tag,
# with the following command:
#   hack/concat-kubernetes-manifests.sh $(find contrib/kube-prometheus/manifests/ \
#     -name "prometheus-*.yaml") > deployed.sls
# In the following, only container image registries have been replaced.

---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus-k8s
  namespace: monitoring
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: prometheus-k8s-config
  namespace: monitoring
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: prometheus-k8s-config
subjects:
- kind: ServiceAccount
  name: prometheus-k8s
  namespace: monitoring
---
apiVersion: v1
kind: Service
metadata:
  labels:
    prometheus: k8s
  name: prometheus-k8s
  namespace: monitoring
spec:
  ports:
  - name: web
    port: 9090
    targetPort: web
  selector:
    app: prometheus
    prometheus: k8s
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  labels:
    k8s-app: kube-scheduler
  name: kube-scheduler
  namespace: monitoring
spec:
  endpoints:
  - interval: 30s
    port: http-metrics
  jobLabel: k8s-app
  namespaceSelector:
    matchNames:
    - kube-system
  selector:
    matchLabels:
      k8s-app: kube-scheduler
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  labels:
    k8s-app: prometheus
  name: prometheus
  namespace: monitoring
spec:
  endpoints:
  - interval: 30s
    port: web
  selector:
    matchLabels:
      prometheus: k8s
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prometheus-k8s
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prometheus-k8s
subjects:
- kind: ServiceAccount
  name: prometheus-k8s
  namespace: monitoring
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  labels:
    k8s-app: apiserver
  name: kube-apiserver
  namespace: monitoring
spec:
  endpoints:
  - bearerTokenFile: /var/run/secrets/kubernetes.io/serviceaccount/token
    interval: 30s
    metricRelabelings:
    - action: drop
      regex: etcd_(debugging|disk|request|server).*
      sourceLabels:
      - __name__
    port: https
    scheme: https
    tlsConfig:
      caFile: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
      serverName: kubernetes
  jobLabel: component
  namespaceSelector:
    matchNames:
    - default
  selector:
    matchLabels:
      component: apiserver
      provider: kubernetes
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: prometheus-k8s-config
  namespace: monitoring
rules:
- apiGroups:
  - ""
  resources:
  - configmaps
  verbs:
  - get
---
apiVersion: monitoring.coreos.com/v1
kind: Prometheus
metadata:
  labels:
    prometheus: k8s
  name: k8s
  namespace: monitoring
spec:
  alerting:
    alertmanagers:
    - name: alertmanager-main
      namespace: monitoring
      port: web
  baseImage: {{ build_image_name('prometheus') }}
  nodeSelector:
    beta.kubernetes.io/os: linux
    node-role.kubernetes.io/infra: ''
  replicas: 2
  resources:
    requests:
      memory: 400Mi
  ruleSelector:
    matchLabels:
      prometheus: k8s
      role: alert-rules
  serviceAccountName: prometheus-k8s
  serviceMonitorNamespaceSelector: {}
  serviceMonitorSelector: {}
  version: v2.4.3
  tolerations:
  - key: "node-role.kubernetes.io/bootstrap"
    operator: "Exists"
    effect: "NoSchedule"
  - key: "node-role.kubernetes.io/infra"
    operator: "Exists"
    effect: "NoSchedule"
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus-k8s
rules:
- apiGroups:
  - ""
  resources:
  - nodes/metrics
  verbs:
  - get
- nonResourceURLs:
  - /metrics
  verbs:
  - get
---
{%- raw %}
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  labels:
    prometheus: k8s
    role: alert-rules
  name: prometheus-k8s-rules
  namespace: monitoring
spec:
  groups:
  - name: k8s.rules
    rules:
    - expr: |
        sum(rate(container_cpu_usage_seconds_total{job="kubelet", image!="", container_name!=""}[5m])) by (namespace)
      record: namespace:container_cpu_usage_seconds_total:sum_rate
    - expr: |
        sum by (namespace, pod_name, container_name) (
          rate(container_cpu_usage_seconds_total{job="kubelet", image!="", container_name!=""}[5m])
        )
      record: namespace_pod_name_container_name:container_cpu_usage_seconds_total:sum_rate
    - expr: |
        sum(container_memory_usage_bytes{job="kubelet", image!="", container_name!=""}) by (namespace)
      record: namespace:container_memory_usage_bytes:sum
    - expr: |
        sum by (namespace, label_name) (
           sum(rate(container_cpu_usage_seconds_total{job="kubelet", image!="", container_name!=""}[5m])) by (namespace, pod_name)
         * on (namespace, pod_name) group_left(label_name)
           label_replace(kube_pod_labels{job="kube-state-metrics"}, "pod_name", "$1", "pod", "(.*)")
        )
      record: namespace_name:container_cpu_usage_seconds_total:sum_rate
    - expr: |
        sum by (namespace, label_name) (
          sum(container_memory_usage_bytes{job="kubelet",image!="", container_name!=""}) by (pod_name, namespace)
        * on (namespace, pod_name) group_left(label_name)
          label_replace(kube_pod_labels{job="kube-state-metrics"}, "pod_name", "$1", "pod", "(.*)")
        )
      record: namespace_name:container_memory_usage_bytes:sum
    - expr: |
        sum by (namespace, label_name) (
          sum(kube_pod_container_resource_requests_memory_bytes{job="kube-state-metrics"}) by (namespace, pod)
        * on (namespace, pod) group_left(label_name)
          label_replace(kube_pod_labels{job="kube-state-metrics"}, "pod_name", "$1", "pod", "(.*)")
        )
      record: namespace_name:kube_pod_container_resource_requests_memory_bytes:sum
    - expr: |
        sum by (namespace, label_name) (
          sum(kube_pod_container_resource_requests_cpu_cores{job="kube-state-metrics"} and on(pod) kube_pod_status_scheduled{condition="true"}) by (namespace, pod)
        * on (namespace, pod) group_left(label_name)
          label_replace(kube_pod_labels{job="kube-state-metrics"}, "pod_name", "$1", "pod", "(.*)")
        )
      record: namespace_name:kube_pod_container_resource_requests_cpu_cores:sum
  - name: kube-scheduler.rules
    rules:
    - expr: |
        histogram_quantile(0.99, sum(rate(scheduler_e2e_scheduling_latency_microseconds_bucket{job="kube-scheduler"}[5m])) without(instance, pod)) / 1e+06
      labels:
        quantile: "0.99"
      record: cluster_quantile:scheduler_e2e_scheduling_latency:histogram_quantile
    - expr: |
        histogram_quantile(0.99, sum(rate(scheduler_scheduling_algorithm_latency_microseconds_bucket{job="kube-scheduler"}[5m])) without(instance, pod)) / 1e+06
      labels:
        quantile: "0.99"
      record: cluster_quantile:scheduler_scheduling_algorithm_latency:histogram_quantile
    - expr: |
        histogram_quantile(0.99, sum(rate(scheduler_binding_latency_microseconds_bucket{job="kube-scheduler"}[5m])) without(instance, pod)) / 1e+06
      labels:
        quantile: "0.99"
      record: cluster_quantile:scheduler_binding_latency:histogram_quantile
    - expr: |
        histogram_quantile(0.9, sum(rate(scheduler_e2e_scheduling_latency_microseconds_bucket{job="kube-scheduler"}[5m])) without(instance, pod)) / 1e+06
      labels:
        quantile: "0.9"
      record: cluster_quantile:scheduler_e2e_scheduling_latency:histogram_quantile
    - expr: |
        histogram_quantile(0.9, sum(rate(scheduler_scheduling_algorithm_latency_microseconds_bucket{job="kube-scheduler"}[5m])) without(instance, pod)) / 1e+06
      labels:
        quantile: "0.9"
      record: cluster_quantile:scheduler_scheduling_algorithm_latency:histogram_quantile
    - expr: |
        histogram_quantile(0.9, sum(rate(scheduler_binding_latency_microseconds_bucket{job="kube-scheduler"}[5m])) without(instance, pod)) / 1e+06
      labels:
        quantile: "0.9"
      record: cluster_quantile:scheduler_binding_latency:histogram_quantile
    - expr: |
        histogram_quantile(0.5, sum(rate(scheduler_e2e_scheduling_latency_microseconds_bucket{job="kube-scheduler"}[5m])) without(instance, pod)) / 1e+06
      labels:
        quantile: "0.5"
      record: cluster_quantile:scheduler_e2e_scheduling_latency:histogram_quantile
    - expr: |
        histogram_quantile(0.5, sum(rate(scheduler_scheduling_algorithm_latency_microseconds_bucket{job="kube-scheduler"}[5m])) without(instance, pod)) / 1e+06
      labels:
        quantile: "0.5"
      record: cluster_quantile:scheduler_scheduling_algorithm_latency:histogram_quantile
    - expr: |
        histogram_quantile(0.5, sum(rate(scheduler_binding_latency_microseconds_bucket{job="kube-scheduler"}[5m])) without(instance, pod)) / 1e+06
      labels:
        quantile: "0.5"
      record: cluster_quantile:scheduler_binding_latency:histogram_quantile
  - name: kube-apiserver.rules
    rules:
    - expr: |
        histogram_quantile(0.99, sum(rate(apiserver_request_latencies_bucket{job="apiserver"}[5m])) without(instance, pod)) / 1e+06
      labels:
        quantile: "0.99"
      record: cluster_quantile:apiserver_request_latencies:histogram_quantile
    - expr: |
        histogram_quantile(0.9, sum(rate(apiserver_request_latencies_bucket{job="apiserver"}[5m])) without(instance, pod)) / 1e+06
      labels:
        quantile: "0.9"
      record: cluster_quantile:apiserver_request_latencies:histogram_quantile
    - expr: |
        histogram_quantile(0.5, sum(rate(apiserver_request_latencies_bucket{job="apiserver"}[5m])) without(instance, pod)) / 1e+06
      labels:
        quantile: "0.5"
      record: cluster_quantile:apiserver_request_latencies:histogram_quantile
  - name: node.rules
    rules:
    - expr: sum(min(kube_pod_info) by (node))
      record: ':kube_pod_info_node_count:'
    - expr: |
        max(label_replace(kube_pod_info{job="kube-state-metrics"}, "pod", "$1", "pod", "(.*)")) by (node, namespace, pod)
      record: 'node_namespace_pod:kube_pod_info:'
    - expr: |
        count by (node) (sum by (node, cpu) (
          node_cpu{job="node-exporter"}
        * on (namespace, pod) group_left(node)
          node_namespace_pod:kube_pod_info:
        ))
      record: node:node_num_cpu:sum
    - expr: |
        1 - avg(rate(node_cpu{job="node-exporter",mode="idle"}[1m]))
      record: :node_cpu_utilisation:avg1m
    - expr: |
        1 - avg by (node) (
          rate(node_cpu{job="node-exporter",mode="idle"}[1m])
        * on (namespace, pod) group_left(node)
          node_namespace_pod:kube_pod_info:)
      record: node:node_cpu_utilisation:avg1m
    - expr: |
        sum(node_load1{job="node-exporter"})
        /
        sum(node:node_num_cpu:sum)
      record: ':node_cpu_saturation_load1:'
    - expr: |
        sum by (node) (
          node_load1{job="node-exporter"}
        * on (namespace, pod) group_left(node)
          node_namespace_pod:kube_pod_info:
        )
        /
        node:node_num_cpu:sum
      record: 'node:node_cpu_saturation_load1:'
    - expr: |
        1 -
        sum(node_memory_MemFree{job="node-exporter"} + node_memory_Cached{job="node-exporter"} + node_memory_Buffers{job="node-exporter"})
        /
        sum(node_memory_MemTotal{job="node-exporter"})
      record: ':node_memory_utilisation:'
    - expr: |
        sum(node_memory_MemFree{job="node-exporter"} + node_memory_Cached{job="node-exporter"} + node_memory_Buffers{job="node-exporter"})
      record: :node_memory_MemFreeCachedBuffers:sum
    - expr: |
        sum(node_memory_MemTotal{job="node-exporter"})
      record: :node_memory_MemTotal:sum
    - expr: |
        sum by (node) (
          (node_memory_MemFree{job="node-exporter"} + node_memory_Cached{job="node-exporter"} + node_memory_Buffers{job="node-exporter"})
          * on (namespace, pod) group_left(node)
            node_namespace_pod:kube_pod_info:
        )
      record: node:node_memory_bytes_available:sum
    - expr: |
        sum by (node) (
          node_memory_MemTotal{job="node-exporter"}
          * on (namespace, pod) group_left(node)
            node_namespace_pod:kube_pod_info:
        )
      record: node:node_memory_bytes_total:sum
    - expr: |
        (node:node_memory_bytes_total:sum - node:node_memory_bytes_available:sum)
        /
        scalar(sum(node:node_memory_bytes_total:sum))
      record: node:node_memory_utilisation:ratio
    - expr: |
        1e3 * sum(
          (rate(node_vmstat_pgpgin{job="node-exporter"}[1m])
         + rate(node_vmstat_pgpgout{job="node-exporter"}[1m]))
        )
      record: :node_memory_swap_io_bytes:sum_rate
    - expr: |
        1 -
        sum by (node) (
          (node_memory_MemFree{job="node-exporter"} + node_memory_Cached{job="node-exporter"} + node_memory_Buffers{job="node-exporter"})
        * on (namespace, pod) group_left(node)
          node_namespace_pod:kube_pod_info:
        )
        /
        sum by (node) (
          node_memory_MemTotal{job="node-exporter"}
        * on (namespace, pod) group_left(node)
          node_namespace_pod:kube_pod_info:
        )
      record: 'node:node_memory_utilisation:'
    - expr: |
        1 - (node:node_memory_bytes_available:sum / node:node_memory_bytes_total:sum)
      record: 'node:node_memory_utilisation_2:'
    - expr: |
        1e3 * sum by (node) (
          (rate(node_vmstat_pgpgin{job="node-exporter"}[1m])
         + rate(node_vmstat_pgpgout{job="node-exporter"}[1m]))
         * on (namespace, pod) group_left(node)
           node_namespace_pod:kube_pod_info:
        )
      record: node:node_memory_swap_io_bytes:sum_rate
    - expr: |
        avg(irate(node_disk_io_time_ms{job="node-exporter",device=~"(sd|xvd|nvme).+"}[1m]) / 1e3)
      record: :node_disk_utilisation:avg_irate
    - expr: |
        avg by (node) (
          irate(node_disk_io_time_ms{job="node-exporter",device=~"(sd|xvd|nvme).+"}[1m]) / 1e3
        * on (namespace, pod) group_left(node)
          node_namespace_pod:kube_pod_info:
        )
      record: node:node_disk_utilisation:avg_irate
    - expr: |
        avg(irate(node_disk_io_time_weighted{job="node-exporter",device=~"(sd|xvd|nvme).+"}[1m]) / 1e3)
      record: :node_disk_saturation:avg_irate
    - expr: |
        avg by (node) (
          irate(node_disk_io_time_weighted{job="node-exporter",device=~"(sd|xvd|nvme).+"}[1m]) / 1e3
        * on (namespace, pod) group_left(node)
          node_namespace_pod:kube_pod_info:
        )
      record: node:node_disk_saturation:avg_irate
    - expr: |
        max by (namespace, pod, device) ((node_filesystem_size{fstype=~"ext[234]|btrfs|xfs|zfs"}
        - node_filesystem_avail{fstype=~"ext[234]|btrfs|xfs|zfs"})
        / node_filesystem_size{fstype=~"ext[234]|btrfs|xfs|zfs"})
      record: 'node:node_filesystem_usage:'
    - expr: |
        max by (namespace, pod, device) (node_filesystem_avail{fstype=~"ext[234]|btrfs|xfs|zfs"} / node_filesystem_size{fstype=~"ext[234]|btrfs|xfs|zfs"})
      record: 'node:node_filesystem_avail:'
    - expr: |
        sum(irate(node_network_receive_bytes{job="node-exporter",device="eth0"}[1m])) +
        sum(irate(node_network_transmit_bytes{job="node-exporter",device="eth0"}[1m]))
      record: :node_net_utilisation:sum_irate
    - expr: |
        sum by (node) (
          (irate(node_network_receive_bytes{job="node-exporter",device="eth0"}[1m]) +
          irate(node_network_transmit_bytes{job="node-exporter",device="eth0"}[1m]))
        * on (namespace, pod) group_left(node)
          node_namespace_pod:kube_pod_info:
        )
      record: node:node_net_utilisation:sum_irate
    - expr: |
        sum(irate(node_network_receive_drop{job="node-exporter",device="eth0"}[1m])) +
        sum(irate(node_network_transmit_drop{job="node-exporter",device="eth0"}[1m]))
      record: :node_net_saturation:sum_irate
    - expr: |
        sum by (node) (
          (irate(node_network_receive_drop{job="node-exporter",device="eth0"}[1m]) +
          irate(node_network_transmit_drop{job="node-exporter",device="eth0"}[1m]))
        * on (namespace, pod) group_left(node)
          node_namespace_pod:kube_pod_info:
        )
      record: node:node_net_saturation:sum_irate
  - name: kube-prometheus-node-recording.rules
    rules:
    - expr: sum(rate(node_cpu{mode!="idle",mode!="iowait"}[3m])) BY (instance)
      record: instance:node_cpu:rate:sum
    - expr: sum((node_filesystem_size{mountpoint="/"} - node_filesystem_free{mountpoint="/"}))
        BY (instance)
      record: instance:node_filesystem_usage:sum
    - expr: sum(rate(node_network_receive_bytes[3m])) BY (instance)
      record: instance:node_network_receive_bytes:rate:sum
    - expr: sum(rate(node_network_transmit_bytes[3m])) BY (instance)
      record: instance:node_network_transmit_bytes:rate:sum
    - expr: sum(rate(node_cpu{mode!="idle",mode!="iowait"}[5m])) WITHOUT (cpu, mode)
        / ON(instance) GROUP_LEFT() count(sum(node_cpu) BY (instance, cpu)) BY (instance)
      record: instance:node_cpu:ratio
    - expr: sum(rate(node_cpu{mode!="idle",mode!="iowait"}[5m]))
      record: cluster:node_cpu:sum_rate5m
    - expr: cluster:node_cpu:rate5m / count(sum(node_cpu) BY (instance, cpu))
      record: cluster:node_cpu:ratio
  - name: node_exporter-16-bcache
    rules:
    - expr: node_bcache_cache_read_races
      record: node_bcache_cache_read_races_total
  - name: node_exporter-16-buddyinfo
    rules:
    - expr: node_buddyinfo_blocks
      record: node_buddyinfo_count
  - name: node_exporter-16-stat
    rules:
    - expr: node_boot_time_seconds
      record: node_boot_time
    - expr: node_context_switches_total
      record: node_context_switches
    - expr: node_forks_total
      record: node_forks
    - expr: node_intr_total
      record: node_intr
  - name: node_exporter-16-cpu
    rules:
    - expr: label_replace(node_cpu_seconds_total, "cpu", "$1", "cpu", "cpu(.+)")
      record: node_cpu
  - name: node_exporter-16-diskstats
    rules:
    - expr: node_disk_read_bytes_total
      record: node_disk_bytes_read
    - expr: node_disk_written_bytes_total
      record: node_disk_bytes_written
    - expr: node_disk_io_time_seconds_total * 1000
      record: node_disk_io_time_ms
    - expr: node_disk_io_time_weighted_seconds_total
      record: node_disk_io_time_weighted
    - expr: node_disk_reads_completed_total
      record: node_disk_reads_completed
    - expr: node_disk_reads_merged_total
      record: node_disk_reads_merged
    - expr: node_disk_read_time_seconds_total * 1000
      record: node_disk_read_time_ms
    - expr: node_disk_writes_completed_total
      record: node_disk_writes_completed
    - expr: node_disk_writes_merged_total
      record: node_disk_writes_merged
    - expr: node_disk_write_time_seconds_total * 1000
      record: node_disk_write_time_ms
  - name: node_exporter-16-filesystem
    rules:
    - expr: node_filesystem_free_bytes
      record: node_filesystem_free
    - expr: node_filesystem_avail_bytes
      record: node_filesystem_avail
    - expr: node_filesystem_size_bytes
      record: node_filesystem_size
  - name: node_exporter-16-infiniband
    rules:
    - expr: node_infiniband_port_data_received_bytes_total
      record: node_infiniband_port_data_received_bytes
    - expr: node_infiniband_port_data_transmitted_bytes_total
      record: node_infiniband_port_data_transmitted_bytes
  - name: node_exporter-16-interrupts
    rules:
    - expr: node_interrupts_total
      record: node_interrupts
  - name: node_exporter-16-memory
    rules:
    - expr: node_memory_Active_bytes
      record: node_memory_Active
    - expr: node_memory_Active_anon_bytes
      record: node_memory_Active_anon
    - expr: node_memory_Active_file_bytes
      record: node_memory_Active_file
    - expr: node_memory_AnonHugePages_bytes
      record: node_memory_AnonHugePages
    - expr: node_memory_AnonPages_bytes
      record: node_memory_AnonPages
    - expr: node_memory_Bounce_bytes
      record: node_memory_Bounce
    - expr: node_memory_Buffers_bytes
      record: node_memory_Buffers
    - expr: node_memory_Cached_bytes
      record: node_memory_Cached
    - expr: node_memory_CommitLimit_bytes
      record: node_memory_CommitLimit
    - expr: node_memory_Committed_AS_bytes
      record: node_memory_Committed_AS
    - expr: node_memory_DirectMap2M_bytes
      record: node_memory_DirectMap2M
    - expr: node_memory_DirectMap4k_bytes
      record: node_memory_DirectMap4k
    - expr: node_memory_Dirty_bytes
      record: node_memory_Dirty
    - expr: node_memory_HardwareCorrupted_bytes
      record: node_memory_HardwareCorrupted
    - expr: node_memory_Hugepagesize_bytes
      record: node_memory_Hugepagesize
    - expr: node_memory_Inactive_bytes
      record: node_memory_Inactive
    - expr: node_memory_Inactive_anon_bytes
      record: node_memory_Inactive_anon
    - expr: node_memory_Inactive_file_bytes
      record: node_memory_Inactive_file
    - expr: node_memory_KernelStack_bytes
      record: node_memory_KernelStack
    - expr: node_memory_Mapped_bytes
      record: node_memory_Mapped
    - expr: node_memory_MemAvailable_bytes
      record: node_memory_MemAvailable
    - expr: node_memory_MemFree_bytes
      record: node_memory_MemFree
    - expr: node_memory_MemTotal_bytes
      record: node_memory_MemTotal
    - expr: node_memory_Mlocked_bytes
      record: node_memory_Mlocked
    - expr: node_memory_NFS_Unstable_bytes
      record: node_memory_NFS_Unstable
    - expr: node_memory_PageTables_bytes
      record: node_memory_PageTables
    - expr: node_memory_Shmem_bytes
      record: node_memory_Shmem
    - expr: node_memory_Slab_bytes
      record: node_memory_Slab
    - expr: node_memory_SReclaimable_bytes
      record: node_memory_SReclaimable
    - expr: node_memory_SUnreclaim_bytes
      record: node_memory_SUnreclaim
    - expr: node_memory_SwapCached_bytes
      record: node_memory_SwapCached
    - expr: node_memory_SwapFree_bytes
      record: node_memory_SwapFree
    - expr: node_memory_SwapTotal_bytes
      record: node_memory_SwapTotal
    - expr: node_memory_Unevictable_bytes
      record: node_memory_Unevictable
    - expr: node_memory_VmallocChunk_bytes
      record: node_memory_VmallocChunk
    - expr: node_memory_VmallocTotal_bytes
      record: node_memory_VmallocTotal
    - expr: node_memory_VmallocUsed_bytes
      record: node_memory_VmallocUsed
    - expr: node_memory_Writeback_bytes
      record: node_memory_Writeback
    - expr: node_memory_WritebackTmp_bytes
      record: node_memory_WritebackTmp
  - name: node_exporter-16-network
    rules:
    - expr: node_network_receive_bytes_total
      record: node_network_receive_bytes
    - expr: node_network_receive_compressed_total
      record: node_network_receive_compressed
    - expr: node_network_receive_drop_total
      record: node_network_receive_drop
    - expr: node_network_receive_errs_total
      record: node_network_receive_errs
    - expr: node_network_receive_fifo_total
      record: node_network_receive_fifo
    - expr: node_network_receive_frame_total
      record: node_network_receive_frame
    - expr: node_network_receive_multicast_total
      record: node_network_receive_multicast
    - expr: node_network_receive_packets_total
      record: node_network_receive_packets
    - expr: node_network_transmit_bytes_total
      record: node_network_transmit_bytes
    - expr: node_network_transmit_compressed_total
      record: node_network_transmit_compressed
    - expr: node_network_transmit_drop_total
      record: node_network_transmit_drop
    - expr: node_network_transmit_errs_total
      record: node_network_transmit_errs
    - expr: node_network_transmit_fifo_total
      record: node_network_transmit_fifo
    - expr: node_network_transmit_frame_total
      record: node_network_transmit_frame
    - expr: node_network_transmit_multicast_total
      record: node_network_transmit_multicast
    - expr: node_network_transmit_packets_total
      record: node_network_transmit_packets
  - name: node_exporter-16-nfs
    rules:
    - expr: node_nfs_connections_total
      record: node_nfs_net_connections
    - expr: node_nfs_packets_total
      record: node_nfs_net_reads
    - expr: label_replace(label_replace(node_nfs_requests_total, "proto", "$1", "version",
        "(.+)"), "method", "$1", "procedure", "(.+)")
      record: node_nfs_procedures
    - expr: node_nfs_rpc_authentication_refreshes_total
      record: node_nfs_rpc_authentication_refreshes
    - expr: node_nfs_rpcs_total
      record: node_nfs_rpc_operations
    - expr: node_nfs_rpc_retransmissions_total
      record: node_nfs_rpc_retransmissions
  - name: node_exporter-16-textfile
    rules:
    - expr: node_textfile_mtime_seconds
      record: node_textfile_mtime
  - name: kubernetes-absent
    rules:
    - alert: AlertmanagerDown
      annotations:
        message: Alertmanager has disappeared from Prometheus target discovery.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-alertmanagerdown
      expr: |
        absent(up{job="alertmanager-main"} == 1)
      for: 15m
      labels:
        severity: critical
    - alert: KubeAPIDown
      annotations:
        message: KubeAPI has disappeared from Prometheus target discovery.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubeapidown
      expr: |
        absent(up{job="apiserver"} == 1)
      for: 15m
      labels:
        severity: critical
    - alert: KubeControllerManagerDown
      annotations:
        message: KubeControllerManager has disappeared from Prometheus target discovery.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubecontrollermanagerdown
      expr: |
        absent(up{job="kube-controller-manager"} == 1)
      for: 15m
      labels:
        severity: critical
    - alert: KubeSchedulerDown
      annotations:
        message: KubeScheduler has disappeared from Prometheus target discovery.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubeschedulerdown
      expr: |
        absent(up{job="kube-scheduler"} == 1)
      for: 15m
      labels:
        severity: critical
    - alert: KubeStateMetricsDown
      annotations:
        message: KubeStateMetrics has disappeared from Prometheus target discovery.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubestatemetricsdown
      expr: |
        absent(up{job="kube-state-metrics"} == 1)
      for: 15m
      labels:
        severity: critical
    - alert: KubeletDown
      annotations:
        message: Kubelet has disappeared from Prometheus target discovery.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubeletdown
      expr: |
        absent(up{job="kubelet"} == 1)
      for: 15m
      labels:
        severity: critical
    - alert: NodeExporterDown
      annotations:
        message: NodeExporter has disappeared from Prometheus target discovery.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-nodeexporterdown
      expr: |
        absent(up{job="node-exporter"} == 1)
      for: 15m
      labels:
        severity: critical
    - alert: PrometheusDown
      annotations:
        message: Prometheus has disappeared from Prometheus target discovery.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-prometheusdown
      expr: |
        absent(up{job="prometheus-k8s"} == 1)
      for: 15m
      labels:
        severity: critical
    - alert: PrometheusOperatorDown
      annotations:
        message: PrometheusOperator has disappeared from Prometheus target discovery.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-prometheusoperatordown
      expr: |
        absent(up{job="prometheus-operator"} == 1)
      for: 15m
      labels:
        severity: critical
  - name: kubernetes-apps
    rules:
    - alert: KubePodCrashLooping
      annotations:
        message: Pod {{ $labels.namespace }}/{{ $labels.pod }} ({{ $labels.container
          }}) is restarting {{ printf "%.2f" $value }} times / 5 minutes.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubepodcrashlooping
      expr: |
        rate(kube_pod_container_status_restarts_total{job="kube-state-metrics"}[15m]) * 60 * 5 > 0
      for: 1h
      labels:
        severity: critical
    - alert: KubePodNotReady
      annotations:
        message: Pod {{ $labels.namespace }}/{{ $labels.pod }} has been in a non-ready
          state for longer than an hour.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubepodnotready
      expr: |
        sum by (namespace, pod) (kube_pod_status_phase{job="kube-state-metrics", phase=~"Pending|Unknown"}) > 0
      for: 1h
      labels:
        severity: critical
    - alert: KubeDeploymentGenerationMismatch
      annotations:
        message: Deployment generation for {{ $labels.namespace }}/{{ $labels.deployment
          }} does not match, this indicates that the Deployment has failed but has
          not been rolled back.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubedeploymentgenerationmismatch
      expr: |
        kube_deployment_status_observed_generation{job="kube-state-metrics"}
          !=
        kube_deployment_metadata_generation{job="kube-state-metrics"}
      for: 15m
      labels:
        severity: critical
    - alert: KubeDeploymentReplicasMismatch
      annotations:
        message: Deployment {{ $labels.namespace }}/{{ $labels.deployment }} has not
          matched the expected number of replicas for longer than an hour.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubedeploymentreplicasmismatch
      expr: |
        kube_deployment_spec_replicas{job="kube-state-metrics"}
          !=
        kube_deployment_status_replicas_available{job="kube-state-metrics"}
      for: 1h
      labels:
        severity: critical
    - alert: KubeStatefulSetReplicasMismatch
      annotations:
        message: StatefulSet {{ $labels.namespace }}/{{ $labels.statefulset }} has
          not matched the expected number of replicas for longer than 15 minutes.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubestatefulsetreplicasmismatch
      expr: |
        kube_statefulset_status_replicas_ready{job="kube-state-metrics"}
          !=
        kube_statefulset_status_replicas{job="kube-state-metrics"}
      for: 15m
      labels:
        severity: critical
    - alert: KubeStatefulSetGenerationMismatch
      annotations:
        message: StatefulSet generation for {{ $labels.namespace }}/{{ $labels.statefulset
          }} does not match, this indicates that the StatefulSet has failed but has
          not been rolled back.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubestatefulsetgenerationmismatch
      expr: |
        kube_statefulset_status_observed_generation{job="kube-state-metrics"}
          !=
        kube_statefulset_metadata_generation{job="kube-state-metrics"}
      for: 15m
      labels:
        severity: critical
    - alert: KubeStatefulSetUpdateNotRolledOut
      annotations:
        message: StatefulSet {{ $labels.namespace }}/{{ $labels.statefulset }} update
          has not been rolled out.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubestatefulsetupdatenotrolledout
      expr: |
        max without (revision) (
          kube_statefulset_status_current_revision{job="kube-state-metrics"}
            unless
          kube_statefulset_status_update_revision{job="kube-state-metrics"}
        )
          *
        (
          kube_statefulset_replicas{job="kube-state-metrics"}
            !=
          kube_statefulset_status_replicas_updated{job="kube-state-metrics"}
        )
      for: 15m
      labels:
        severity: critical
    - alert: KubeDaemonSetRolloutStuck
      annotations:
        message: Only {{ $value }}% of the desired Pods of DaemonSet {{ $labels.namespace
          }}/{{ $labels.daemonset }} are scheduled and ready.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubedaemonsetrolloutstuck
      expr: |
        kube_daemonset_status_number_ready{job="kube-state-metrics"}
          /
        kube_daemonset_status_desired_number_scheduled{job="kube-state-metrics"} * 100 < 100
      for: 15m
      labels:
        severity: critical
    - alert: KubeDaemonSetNotScheduled
      annotations:
        message: '{{ $value }} Pods of DaemonSet {{ $labels.namespace }}/{{ $labels.daemonset
          }} are not scheduled.'
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubedaemonsetnotscheduled
      expr: |
        kube_daemonset_status_desired_number_scheduled{job="kube-state-metrics"}
          -
        kube_daemonset_status_current_number_scheduled{job="kube-state-metrics"} > 0
      for: 10m
      labels:
        severity: warning
    - alert: KubeDaemonSetMisScheduled
      annotations:
        message: '{{ $value }} Pods of DaemonSet {{ $labels.namespace }}/{{ $labels.daemonset
          }} are running where they are not supposed to run.'
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubedaemonsetmisscheduled
      expr: |
        kube_daemonset_status_number_misscheduled{job="kube-state-metrics"} > 0
      for: 10m
      labels:
        severity: warning
    - alert: KubeCronJobRunning
      annotations:
        message: CronJob {{ $labels.namespaces }}/{{ $labels.cronjob }} is taking
          more than 1h to complete.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubecronjobrunning
      expr: |
        time() - kube_cronjob_next_schedule_time{job="kube-state-metrics"} > 3600
      for: 1h
      labels:
        severity: warning
    - alert: KubeJobCompletion
      annotations:
        message: Job {{ $labels.namespaces }}/{{ $labels.job }} is taking more than
          one hour to complete.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubejobcompletion
      expr: |
        kube_job_spec_completions{job="kube-state-metrics"} - kube_job_status_succeeded{job="kube-state-metrics"}  > 0
      for: 1h
      labels:
        severity: warning
    - alert: KubeJobFailed
      annotations:
        message: Job {{ $labels.namespaces }}/{{ $labels.job }} failed to complete.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubejobfailed
      expr: |
        kube_job_status_failed{job="kube-state-metrics"}  > 0
      for: 1h
      labels:
        severity: warning
  - name: kubernetes-resources
    rules:
    - alert: KubeCPUOvercommit
      annotations:
        message: Cluster has overcommitted CPU resource requests for Pods and cannot
          tolerate node failure.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubecpuovercommit
      expr: |
        sum(namespace_name:kube_pod_container_resource_requests_cpu_cores:sum)
          /
        sum(node:node_num_cpu:sum)
          >
        (count(node:node_num_cpu:sum)-1) / count(node:node_num_cpu:sum)
      for: 5m
      labels:
        severity: warning
    - alert: KubeMemOvercommit
      annotations:
        message: Cluster has overcommitted memory resource requests for Pods and cannot
          tolerate node failure.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubememovercommit
      expr: |
        sum(namespace_name:kube_pod_container_resource_requests_memory_bytes:sum)
          /
        sum(node_memory_MemTotal)
          >
        (count(node:node_num_cpu:sum)-1)
          /
        count(node:node_num_cpu:sum)
      for: 5m
      labels:
        severity: warning
    - alert: KubeCPUOvercommit
      annotations:
        message: Cluster has overcommitted CPU resource requests for Namespaces.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubecpuovercommit
      expr: |
        sum(kube_resourcequota{job="kube-state-metrics", type="hard", resource="requests.cpu"})
          /
        sum(node:node_num_cpu:sum)
          > 1.5
      for: 5m
      labels:
        severity: warning
    - alert: KubeMemOvercommit
      annotations:
        message: Cluster has overcommitted memory resource requests for Namespaces.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubememovercommit
      expr: |
        sum(kube_resourcequota{job="kube-state-metrics", type="hard", resource="requests.memory"})
          /
        sum(node_memory_MemTotal{job="node-exporter"})
          > 1.5
      for: 5m
      labels:
        severity: warning
    - alert: KubeQuotaExceeded
      annotations:
        message: Namespace {{ $labels.namespace }} is using {{ printf "%0.0f" $value
          }}% of its {{ $labels.resource }} quota.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubequotaexceeded
      expr: |
        100 * kube_resourcequota{job="kube-state-metrics", type="used"}
          / ignoring(instance, job, type)
        (kube_resourcequota{job="kube-state-metrics", type="hard"} > 0)
          > 90
      for: 15m
      labels:
        severity: warning
    - alert: CPUThrottlingHigh
      annotations:
        message: '{{ printf "%0.0f" $value }}% throttling of CPU in namespace {{ $labels.namespace
          }} for {{ $labels.container_name }}.'
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-cputhrottlinghigh
      expr: "100 * sum(increase(container_cpu_cfs_throttled_periods_total[5m])) by
        (container_name, pod_name, namespace) \n  / \nsum(increase(container_cpu_cfs_periods_total[5m]))
        by (container_name, pod_name, namespace)\n  > 25 \n"
      for: 15m
      labels:
        severity: warning
  - name: kubernetes-storage
    rules:
    - alert: KubePersistentVolumeUsageCritical
      annotations:
        message: The PersistentVolume claimed by {{ $labels.persistentvolumeclaim
          }} in Namespace {{ $labels.namespace }} is only {{ printf "%0.0f" $value
          }}% free.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubepersistentvolumeusagecritical
      expr: |
        100 * kubelet_volume_stats_available_bytes{job="kubelet"}
          /
        kubelet_volume_stats_capacity_bytes{job="kubelet"}
          < 3
      for: 1m
      labels:
        severity: critical
    - alert: KubePersistentVolumeFullInFourDays
      annotations:
        message: Based on recent sampling, the PersistentVolume claimed by {{ $labels.persistentvolumeclaim
          }} in Namespace {{ $labels.namespace }} is expected to fill up within four
          days. Currently {{ $value }} bytes are available.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubepersistentvolumefullinfourdays
      expr: |
        (
          kubelet_volume_stats_used_bytes{job="kubelet"}
            /
          kubelet_volume_stats_capacity_bytes{job="kubelet"}
        ) > 0.85
        and
        predict_linear(kubelet_volume_stats_available_bytes{job="kubelet"}[6h], 4 * 24 * 3600) < 0
      for: 5m
      labels:
        severity: critical
  - name: kubernetes-system
    rules:
    - alert: KubeNodeNotReady
      annotations:
        message: '{{ $labels.node }} has been unready for more than an hour.'
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubenodenotready
      expr: |
        kube_node_status_condition{job="kube-state-metrics",condition="Ready",status="true"} == 0
      for: 1h
      labels:
        severity: warning
    - alert: KubeVersionMismatch
      annotations:
        message: There are {{ $value }} different versions of Kubernetes components
          running.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubeversionmismatch
      expr: |
        count(count(kubernetes_build_info{job!="kube-dns"}) by (gitVersion)) > 1
      for: 1h
      labels:
        severity: warning
    - alert: KubeClientErrors
      annotations:
        message: Kubernetes API server client '{{ $labels.job }}/{{ $labels.instance
          }}' is experiencing {{ printf "%0.0f" $value }}% errors.'
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubeclienterrors
      expr: |
        (sum(rate(rest_client_requests_total{code!~"2..|404"}[5m])) by (instance, job)
          /
        sum(rate(rest_client_requests_total[5m])) by (instance, job))
        * 100 > 1
      for: 15m
      labels:
        severity: warning
    - alert: KubeClientErrors
      annotations:
        message: Kubernetes API server client '{{ $labels.job }}/{{ $labels.instance
          }}' is experiencing {{ printf "%0.0f" $value }} errors / second.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubeclienterrors
      expr: |
        sum(rate(ksm_scrape_error_total{job="kube-state-metrics"}[5m])) by (instance, job) > 0.1
      for: 15m
      labels:
        severity: warning
    - alert: KubeletTooManyPods
      annotations:
        message: Kubelet {{ $labels.instance }} is running {{ $value }} Pods, close
          to the limit of 110.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubelettoomanypods
      expr: |
        kubelet_running_pod_count{job="kubelet"} > 110 * 0.9
      for: 15m
      labels:
        severity: warning
    - alert: KubeAPILatencyHigh
      annotations:
        message: The API server has a 99th percentile latency of {{ $value }} seconds
          for {{ $labels.verb }} {{ $labels.resource }}.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubeapilatencyhigh
      expr: |
        cluster_quantile:apiserver_request_latencies:histogram_quantile{job="apiserver",quantile="0.99",subresource!="log",verb!~"^(?:LIST|WATCH|WATCHLIST|PROXY|CONNECT)$"} > 1
      for: 10m
      labels:
        severity: warning
    - alert: KubeAPILatencyHigh
      annotations:
        message: The API server has a 99th percentile latency of {{ $value }} seconds
          for {{ $labels.verb }} {{ $labels.resource }}.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubeapilatencyhigh
      expr: |
        cluster_quantile:apiserver_request_latencies:histogram_quantile{job="apiserver",quantile="0.99",subresource!="log",verb!~"^(?:LIST|WATCH|WATCHLIST|PROXY|CONNECT)$"} > 4
      for: 10m
      labels:
        severity: critical
    - alert: KubeAPIErrorsHigh
      annotations:
        message: API server is returning errors for {{ $value }}% of requests.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubeapierrorshigh
      expr: |
        sum(rate(apiserver_request_count{job="apiserver",code=~"^(?:5..)$"}[5m])) without(instance, pod)
          /
        sum(rate(apiserver_request_count{job="apiserver"}[5m])) without(instance, pod) * 100 > 10
      for: 10m
      labels:
        severity: critical
    - alert: KubeAPIErrorsHigh
      annotations:
        message: API server is returning errors for {{ $value }}% of requests.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubeapierrorshigh
      expr: |
        sum(rate(apiserver_request_count{job="apiserver",code=~"^(?:5..)$"}[5m])) without(instance, pod)
          /
        sum(rate(apiserver_request_count{job="apiserver"}[5m])) without(instance, pod) * 100 > 5
      for: 10m
      labels:
        severity: warning
    - alert: KubeClientCertificateExpiration
      annotations:
        message: Kubernetes API certificate is expiring in less than 7 days.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubeclientcertificateexpiration
      expr: |
        histogram_quantile(0.01, sum by (job, le) (rate(apiserver_client_certificate_expiration_seconds_bucket{job="apiserver"}[5m]))) < 604800
      labels:
        severity: warning
    - alert: KubeClientCertificateExpiration
      annotations:
        message: Kubernetes API certificate is expiring in less than 24 hours.
        runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-kubeclientcertificateexpiration
      expr: |
        histogram_quantile(0.01, sum by (job, le) (rate(apiserver_client_certificate_expiration_seconds_bucket{job="apiserver"}[5m]))) < 86400
      labels:
        severity: critical
  - name: alertmanager.rules
    rules:
    - alert: AlertmanagerConfigInconsistent
      annotations:
        message: The configuration of the instances of the Alertmanager cluster `{{$labels.service}}`
          are out of sync.
      expr: |
        count_values("config_hash", alertmanager_config_hash{job="alertmanager-main"}) BY (service) / ON(service) GROUP_LEFT() label_replace(prometheus_operator_spec_replicas{job="prometheus-operator"}, "service", "alertmanager-$1", "alertmanager", "(.*)") != 1
      for: 5m
      labels:
        severity: critical
    - alert: AlertmanagerFailedReload
      annotations:
        message: Reloading Alertmanager's configuration has failed for {{ $labels.namespace
          }}/{{ $labels.pod}}.
      expr: |
        alertmanager_config_last_reload_successful{job="alertmanager-main"} == 0
      for: 10m
      labels:
        severity: warning
  - name: general.rules
    rules:
    - alert: TargetDown
      annotations:
        message: '{{ $value }}% of the {{ $labels.job }} targets are down.'
      expr: 100 * (count(up == 0) BY (job) / count(up) BY (job)) > 10
      for: 10m
      labels:
        severity: warning
    - alert: DeadMansSwitch
      annotations:
        message: This is a DeadMansSwitch meant to ensure that the entire alerting
          pipeline is functional.
      expr: vector(1)
      labels:
        severity: none
  - name: kube-prometheus-node-alerting.rules
    rules:
    - alert: NodeDiskRunningFull
      annotations:
        message: Device {{ $labels.device }} of node-exporter {{ $labels.namespace
          }}/{{ $labels.pod }} will be full within the next 24 hours.
      expr: |
        (node:node_filesystem_usage: > 0.85) and (predict_linear(node:node_filesystem_avail:[6h], 3600 * 24) < 0)
      for: 30m
      labels:
        severity: warning
    - alert: NodeDiskRunningFull
      annotations:
        message: Device {{ $labels.device }} of node-exporter {{ $labels.namespace
          }}/{{ $labels.pod }} will be full within the next 2 hours.
      expr: |
        (node:node_filesystem_usage: > 0.85) and (predict_linear(node:node_filesystem_avail:[30m], 3600 * 2) < 0)
      for: 10m
      labels:
        severity: critical
  - name: prometheus.rules
    rules:
    - alert: PrometheusConfigReloadFailed
      annotations:
        description: Reloading Prometheus' configuration has failed for {{$labels.namespace}}/{{$labels.pod}}
        summary: Reloading Promehteus' configuration failed
      expr: |
        prometheus_config_last_reload_successful{job="prometheus-k8s"} == 0
      for: 10m
      labels:
        severity: warning
    - alert: PrometheusNotificationQueueRunningFull
      annotations:
        description: Prometheus' alert notification queue is running full for {{$labels.namespace}}/{{
          $labels.pod}}
        summary: Prometheus' alert notification queue is running full
      expr: |
        predict_linear(prometheus_notifications_queue_length{job="prometheus-k8s"}[5m], 60 * 30) > prometheus_notifications_queue_capacity{job="prometheus-k8s"}
      for: 10m
      labels:
        severity: warning
    - alert: PrometheusErrorSendingAlerts
      annotations:
        description: Errors while sending alerts from Prometheus {{$labels.namespace}}/{{
          $labels.pod}} to Alertmanager {{$labels.Alertmanager}}
        summary: Errors while sending alert from Prometheus
      expr: |
        rate(prometheus_notifications_errors_total{job="prometheus-k8s"}[5m]) / rate(prometheus_notifications_sent_total{job="prometheus-k8s"}[5m]) > 0.01
      for: 10m
      labels:
        severity: warning
    - alert: PrometheusErrorSendingAlerts
      annotations:
        description: Errors while sending alerts from Prometheus {{$labels.namespace}}/{{
          $labels.pod}} to Alertmanager {{$labels.Alertmanager}}
        summary: Errors while sending alerts from Prometheus
      expr: |
        rate(prometheus_notifications_errors_total{job="prometheus-k8s"}[5m]) / rate(prometheus_notifications_sent_total{job="prometheus-k8s"}[5m]) > 0.03
      for: 10m
      labels:
        severity: critical
    - alert: PrometheusNotConnectedToAlertmanagers
      annotations:
        description: Prometheus {{ $labels.namespace }}/{{ $labels.pod}} is not connected
          to any Alertmanagers
        summary: Prometheus is not connected to any Alertmanagers
      expr: |
        prometheus_notifications_alertmanagers_discovered{job="prometheus-k8s"} < 1
      for: 10m
      labels:
        severity: warning
    - alert: PrometheusTSDBReloadsFailing
      annotations:
        description: '{{$labels.job}} at {{$labels.instance}} had {{$value | humanize}}
          reload failures over the last four hours.'
        summary: Prometheus has issues reloading data blocks from disk
      expr: |
        increase(prometheus_tsdb_reloads_failures_total{job="prometheus-k8s"}[2h]) > 0
      for: 12h
      labels:
        severity: warning
    - alert: PrometheusTSDBCompactionsFailing
      annotations:
        description: '{{$labels.job}} at {{$labels.instance}} had {{$value | humanize}}
          compaction failures over the last four hours.'
        summary: Prometheus has issues compacting sample blocks
      expr: |
        increase(prometheus_tsdb_compactions_failed_total{job="prometheus-k8s"}[2h]) > 0
      for: 12h
      labels:
        severity: warning
    - alert: PrometheusTSDBWALCorruptions
      annotations:
        description: '{{$labels.job}} at {{$labels.instance}} has a corrupted write-ahead
          log (WAL).'
        summary: Prometheus write-ahead log is corrupted
      expr: |
        tsdb_wal_corruptions_total{job="prometheus-k8s"} > 0
      for: 4h
      labels:
        severity: warning
    - alert: PrometheusNotIngestingSamples
      annotations:
        description: Prometheus {{ $labels.namespace }}/{{ $labels.pod}} isn't ingesting
          samples.
        summary: Prometheus isn't ingesting samples
      expr: |
        rate(prometheus_tsdb_head_samples_appended_total{job="prometheus-k8s"}[5m]) <= 0
      for: 10m
      labels:
        severity: warning
    - alert: PrometheusTargetScrapesDuplicate
      annotations:
        description: '{{$labels.namespace}}/{{$labels.pod}} has many samples rejected
          due to duplicate timestamps but different values'
        summary: Prometheus has many samples rejected
      expr: |
        increase(prometheus_target_scrapes_sample_duplicate_timestamp_total{job="prometheus-k8s"}[5m]) > 0
      for: 10m
      labels:
        severity: warning
  - name: prometheus-operator
    rules:
    - alert: PrometheusOperatorReconcileErrors
      annotations:
        message: Errors while reconciling {{ $labels.controller }} in {{ $labels.namespace
          }} Namespace.
      expr: |
        rate(prometheus_operator_reconcile_errors_total{job="prometheus-operator"}[5m]) > 0.1
      for: 10m
      labels:
        severity: warning
    - alert: PrometheusOperatorNodeLookupErrors
      annotations:
        message: Errors while reconciling Prometheus in {{ $labels.namespace }} Namespace.
      expr: |
        rate(prometheus_operator_node_address_lookup_errors_total{job="prometheus-operator"}[5m]) > 0.1
      for: 10m
      labels:
        severity: warning
{%- endraw %}
---
apiVersion: rbac.authorization.k8s.io/v1
items:
- apiVersion: rbac.authorization.k8s.io/v1
  kind: RoleBinding
  metadata:
    name: prometheus-k8s
    namespace: default
  roleRef:
    apiGroup: rbac.authorization.k8s.io
    kind: Role
    name: prometheus-k8s
  subjects:
  - kind: ServiceAccount
    name: prometheus-k8s
    namespace: monitoring
- apiVersion: rbac.authorization.k8s.io/v1
  kind: RoleBinding
  metadata:
    name: prometheus-k8s
    namespace: kube-system
  roleRef:
    apiGroup: rbac.authorization.k8s.io
    kind: Role
    name: prometheus-k8s
  subjects:
  - kind: ServiceAccount
    name: prometheus-k8s
    namespace: monitoring
- apiVersion: rbac.authorization.k8s.io/v1
  kind: RoleBinding
  metadata:
    name: prometheus-k8s
    namespace: monitoring
  roleRef:
    apiGroup: rbac.authorization.k8s.io
    kind: Role
    name: prometheus-k8s
  subjects:
  - kind: ServiceAccount
    name: prometheus-k8s
    namespace: monitoring
kind: RoleBindingList
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  labels:
    k8s-app: coredns
  name: coredns
  namespace: monitoring
spec:
  endpoints:
  - bearerTokenFile: /var/run/secrets/kubernetes.io/serviceaccount/token
    interval: 15s
    port: metrics
  jobLabel: k8s-app
  namespaceSelector:
    matchNames:
    - kube-system
  selector:
    matchLabels:
      k8s-app: kube-dns
---
apiVersion: rbac.authorization.k8s.io/v1
items:
- apiVersion: rbac.authorization.k8s.io/v1
  kind: Role
  metadata:
    name: prometheus-k8s
    namespace: default
  rules:
  - apiGroups:
    - ""
    resources:
    - nodes
    - services
    - endpoints
    - pods
    verbs:
    - get
    - list
    - watch
- apiVersion: rbac.authorization.k8s.io/v1
  kind: Role
  metadata:
    name: prometheus-k8s
    namespace: kube-system
  rules:
  - apiGroups:
    - ""
    resources:
    - nodes
    - services
    - endpoints
    - pods
    verbs:
    - get
    - list
    - watch
- apiVersion: rbac.authorization.k8s.io/v1
  kind: Role
  metadata:
    name: prometheus-k8s
    namespace: monitoring
  rules:
  - apiGroups:
    - ""
    resources:
    - nodes
    - services
    - endpoints
    - pods
    verbs:
    - get
    - list
    - watch
kind: RoleList
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  labels:
    k8s-app: kubelet
  name: kubelet
  namespace: monitoring
spec:
  endpoints:
  - bearerTokenFile: /var/run/secrets/kubernetes.io/serviceaccount/token
    honorLabels: true
    interval: 30s
    port: https-metrics
    scheme: https
    tlsConfig:
      insecureSkipVerify: true
  - bearerTokenFile: /var/run/secrets/kubernetes.io/serviceaccount/token
    honorLabels: true
    interval: 30s
    path: /metrics/cadvisor
    port: https-metrics
    scheme: https
    tlsConfig:
      insecureSkipVerify: true
  jobLabel: k8s-app
  namespaceSelector:
    matchNames:
    - kube-system
  selector:
    matchLabels:
      k8s-app: kubelet
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  labels:
    k8s-app: kube-controller-manager
  name: kube-controller-manager
  namespace: monitoring
spec:
  endpoints:
  - interval: 30s
    metricRelabelings:
    - action: drop
      regex: etcd_(debugging|disk|request|server).*
      sourceLabels:
      - __name__
    port: http-metrics
  jobLabel: k8s-app
  namespaceSelector:
    matchNames:
    - kube-system
  selector:
    matchLabels:
      k8s-app: kube-controller-manager
