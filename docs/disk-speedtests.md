# "SoloSSD" 1x Intenso 128GB SSD USB-3.0

fio --name=readtest --filename=/dev/disk/by-id/ata-INTENSO_AA000000000000005502-part --rw=read --bs=1M --iodepth=32 --numjobs=1 --direct=1 --runtime=30 --time_based --group_reporting --size=1G
readtest: (g=0): rw=read, bs=(R) 1024KiB-1024KiB, (W) 1024KiB-1024KiB, (T) 1024KiB-1024KiB, ioengine=psync, iodepth=32
fio-3.39
Starting 1 process
readtest: Laying out IO file (1 file / 1024MiB)
note: both iodepth >= 1 and synchronous I/O engine are selected, queue depth will be capped at 1
Jobs: 1 (f=1): [R(1)][100.0%][r=9363MiB/s][r=9363 IOPS (eta 00m:00s)]
readtest: (groupid=0, jobs=1): err= 0: pid=1781559: Tue Jan 20 05:45:47 2026
  read: IOPS=9284, BW=9284MiB/s (9735MB/s)(272GiB/30001msec)
    clat (usec): min=91, max=522, avg=107.36, stdev= 9.25
     lat (usec): min=91, max=522, avg=107.40, stdev= 9.25
    clat percentiles (usec):
     | 1.00th=[ 97], 5.00th=[ 99], 10.00th=[ 99], 20.00th=[ 100],
     | 30.00th=[ 102], 40.00th=[ 104], 50.00th=[ 105], 60.00th=[ 109],
     | 70.00th=[ 110], 80.00th=[ 113], 90.00th=[ 119], 95.00th=[ 124],
     | 99.00th=[ 141], 99.50th=[ 149], 99.90th=[ 176], 99.95th=[ 192],
     | 99.99th=[ 227]
   bw ( MiB/s): min= 8856, max= 9460, per=100.00%, avg=9287.53, stdev=135.51, samples=59
   iops        : min= 8856, max= 9460, avg=9287.53, stdev=135.52, samples=59
  lat (usec) : 100=21.38%, 250=78.62%, 500=0.01%, 750=0.01%
  cpu : usr=0.79%, sys=99.07%, ctx=1675, majf=4, minf=265
  IO depths    : 1=100.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     issued rwts: total=278542,0,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency : target=0, window=0, percentile=100.00%, depth=32

Run status group 0 (all jobs):
   READ: bw=9284MiB/s (9735MB/s), 9284MiB/s-9284MiB/s (9735MB/s-9735MB/s), io=272GiB (292GB), run=30001-30001msec

## Sequential read / write

fio --name=seqrw \
    --directory=/SoloSSD/ \
    --rw=readwrite \
    --bs=1M \
    --size=20G \
    --numjobs=1 \
    --iodepth=32 \
    --direct=1 \
    --group_reporting
seqrw: (g=0): rw=rw, bs=(R) 1024KiB-1024KiB, (W) 1024KiB-1024KiB, (T) 1024KiB-1024KiB, ioengine=psync, iodepth=32
fio-3.39
Starting 1 process
seqrw: Laying out IO file (1 file / 20480MiB)
note: both iodepth >= 1 and synchronous I/O engine are selected, queue depth will be capped at 1
Jobs: 1 (f=1): [M(1)][99.2%][r=67.0MiB/s,w=58.0MiB/s][r=67,w=58 IOPS][eta 00m:03s]
seqrw: (groupid=0, jobs=1): err= 0: pid=1795218: Tue Jan 20 06:04:36 2026
  read: IOPS=26, BW=26.2MiB/s (27.5MB/s)(10.0GiB/391817msec)
    clat (msec): min=3, max=160, avg=11.60, stdev= 9.62
     lat (msec): min=3, max=160, avg=11.60, stdev= 9.62
    clat percentiles (msec):
     | 1.00th=[    5], 5.00th=[    5], 10.00th=[    5], 20.00th=[    5],
     | 30.00th=[    5], 40.00th=[    5], 50.00th=[    5], 60.00th=[ 15],
     | 70.00th=[ 21], 80.00th=[ 24], 90.00th=[ 24], 95.00th=[ 25],
     | 99.00th=[ 29], 99.50th=[ 40], 99.90th=[ 99], 99.95th=[ 107],
     | 99.99th=[ 126]
   bw ( KiB/s): min= 2048, max=129024, per=100.00%, avg=26924.94, stdev=22441.11, samples=779
   iops        : min=    2, max= 126, avg=26.28, stdev=21.91, samples=779
  write: IOPS=26, BW=26.1MiB/s (27.4MB/s)(9.98GiB/391817msec); 0 zone resets
    clat (msec): min=4, max=215, avg=26.66, stdev=27.26
     lat (msec): min=4, max=215, avg=26.68, stdev=27.26
    clat percentiles (msec):
     | 1.00th=[    6], 5.00th=[    6], 10.00th=[    6], 20.00th=[    6],
     | 30.00th=[    6], 40.00th=[    6], 50.00th=[    7], 60.00th=[ 35],
     | 70.00th=[ 42], 80.00th=[ 57], 90.00th=[ 65], 95.00th=[ 80],
     | 99.00th=[ 86], 99.50th=[ 97], 99.90th=[ 153], 99.95th=[ 159],
     | 99.99th=[ 171]
   bw ( KiB/s): min= 2048, max=106496, per=99.91%, avg=26690.64, stdev=20515.35, samples=783
   iops        : min=    2, max= 104, avg=26.05, stdev=20.03, samples=783
  lat (msec) : 4=0.28%, 10=57.36%, 20=6.59%, 50=23.37%, 100=12.11%
  lat (msec) : 250=0.28%
  cpu : usr=0.13%, sys=6.80%, ctx=91693, majf=0, minf=9
  IO depths    : 1=100.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     issued rwts: total=10258,10222,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency : target=0, window=0, percentile=100.00%, depth=32

Run status group 0 (all jobs):
   READ: bw=26.2MiB/s (27.5MB/s), 26.2MiB/s-26.2MiB/s (27.5MB/s-27.5MB/s), io=10.0GiB (10.8GB), run=391817-391817msec
  WRITE: bw=26.1MiB/s (27.4MB/s), 26.1MiB/s-26.1MiB/s (27.4MB/s-27.4MB/s), io=9.98GiB (10.7GB), run=391817-391817msec

## Random IOPS

fio --name=randrw \
    --directory=/SoloSSD/ \
    --rw=randrw \
    --bs=4k \
    --size=5G \
    --numjobs=4 \
    --iodepth=32 \
    --direct=1 \
    --group_reporting
randrw: (g=0): rw=randrw, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=psync, iodepth=32
...
fio-3.39
Starting 4 processes
randrw: Laying out IO file (1 file / 5120MiB)
randrw: Laying out IO file (1 file / 5120MiB)
randrw: Laying out IO file (1 file / 5120MiB)
randrw: Laying out IO file (1 file / 5120MiB)
note: both iodepth >= 1 and synchronous I/O engine are selected, queue depth will be capped at 1
note: both iodepth >= 1 and synchronous I/O engine are selected, queue depth will be capped at 1
note: both iodepth >= 1 and synchronous I/O engine are selected, queue depth will be capped at 1
note: both iodepth >= 1 and synchronous I/O engine are selected, queue depth will be capped at 1
^Cbs: 4 (f=4): [m(4)][0.1%][r=60KiB/s,w=72KiB/s][r=15,w=18 IOPS][eta 08h:09m:01s]
fio: terminating on signal 2

randrw: (groupid=0, jobs=4): err= 0: pid=1822643: Tue Jan 20 06:25:45 2026
  read: IOPS=92, BW=371KiB/s (380kB/s)(9.82MiB/27101msec)
    clat (usec): min=8, max=401038, avg=22219.32, stdev=54877.28
     lat (usec): min=8, max=401038, avg=22219.52, stdev=54877.30
    clat percentiles (usec):
     | 1.00th=[ 1483], 5.00th=[ 2900], 10.00th=[ 2933], 20.00th=[ 2966],
     | 30.00th=[ 2999], 40.00th=[ 3064], 50.00th=[ 3097], 60.00th=[ 3163],
     | 70.00th=[ 3261], 80.00th=[ 3458], 90.00th=[ 76022], 95.00th=[158335],
     | 99.00th=[248513], 99.50th=[320865], 99.90th=[387974], 99.95th=[396362],
     | 99.99th=[400557]
   bw ( KiB/s): min= 32, max= 2880, per=100.00%, avg=410.41, stdev=213.28, samples=196
   iops        : min=    8, max= 720, avg=102.60, stdev=53.32, samples=196
  write: IOPS=96, BW=387KiB/s (396kB/s)(10.2MiB/27101msec); 0 zone resets
    clat (usec): min=10, max=404481, avg=20049.26, stdev=52526.91
     lat (usec): min=10, max=404481, avg=20049.52, stdev=52526.97
    clat percentiles (usec):
     | 1.00th=[    28], 5.00th=[    36], 10.00th=[    41], 20.00th=[ 2933],
     | 30.00th=[ 2999], 40.00th=[ 3032], 50.00th=[ 3064], 60.00th=[ 3130],
     | 70.00th=[ 3195], 80.00th=[ 3359], 90.00th=[ 53740], 95.00th=[158335],
     | 99.00th=[244319], 99.50th=[299893], 99.90th=[329253], 99.95th=[350225],
     | 99.99th=[404751]
   bw ( KiB/s): min= 32, max= 3040, per=100.00%, avg=413.94, stdev=218.16, samples=203
   iops        : min=    8, max= 760, avg=103.49, stdev=54.54, samples=203
  lat (usec) : 10=0.14%, 20=0.58%, 50=5.57%, 100=0.49%
  lat (msec) : 2=0.80%, 4=75.01%, 10=0.84%, 20=0.16%, 50=5.20%
  lat (msec) : 100=4.13%, 250=6.27%, 500=0.82%
  cpu : usr=0.02%, sys=0.25%, ctx=9960, majf=0, minf=42
  IO depths    : 1=100.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     issued rwts: total=2513,2621,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency : target=0, window=0, percentile=100.00%, depth=32

Run status group 0 (all jobs):
   READ: bw=371KiB/s (380kB/s), 371KiB/s-371KiB/s (380kB/s-380kB/s), io=9.82MiB (10.3MB), run=27101-27101msec
  WRITE: bw=387KiB/s (396kB/s), 387KiB/s-387KiB/s (396kB/s-396kB/s), io=10.2MiB (10.7MB), run=27101-27101msec

## SSD ZFS Spedtest

fio --name=zfs-seq \
    --directory=/SoloSSD/testbench \
    --rw=readwrite \
    --bs=128k \
    --size=20G \
    --numjobs=1 \
    --iodepth=16 \
    --direct=1
zfs-seq: (g=0): rw=rw, bs=(R) 128KiB-128KiB, (W) 128KiB-128KiB, (T) 128KiB-128KiB, ioengine=psync, iodepth=16
fio-3.39
Starting 1 process
zfs-seq: Laying out IO file (1 file / 20480MiB)
note: both iodepth >= 1 and synchronous I/O engine are selected, queue depth will be capped at 1
Jobs: 1 (f=1): [M(1)][99.7%][r=66.9MiB/s,w=70.6MiB/s][r=535,w=565 IOPS][eta 00m:01s]
zfs-seq: (groupid=0, jobs=1): err= 0: pid=1837794: Tue Jan 20 06:42:28 2026
  read: IOPS=237, BW=29.7MiB/s (31.1MB/s)(10.0GiB/345472msec)
    clat (usec): min=597, max=115052, avg=3034.43, stdev=6638.45
     lat (usec): min=597, max=115052, avg=3034.61, stdev=6638.45
    clat percentiles (usec):
     | 1.00th=[ 619], 5.00th=[ 668], 10.00th=[ 701], 20.00th=[ 750],
     | 30.00th=[ 799], 40.00th=[ 840], 50.00th=[ 881], 60.00th=[ 938],
     | 70.00th=[ 988], 80.00th=[ 1074], 90.00th=[ 12256], 95.00th=[ 18744],
     | 99.00th=[ 20841], 99.50th=[ 23200], 99.90th=[ 93848], 99.95th=[ 94897],
     | 99.99th=[106431]
   bw ( KiB/s): min= 1792, max=93696, per=99.85%, avg=30366.75, stdev=25640.51, samples=690
   iops        : min= 14, max= 732, avg=237.24, stdev=200.32, samples=690
  write: IOPS=236, BW=29.6MiB/s (31.0MB/s)(9.98GiB/345472msec); 0 zone resets
    clat (usec): min=613, max=112595, avg=1173.23, stdev=2520.76
     lat (usec): min=616, max=112599, avg=1175.78, stdev=2520.89
    clat percentiles (usec):
     | 1.00th=[ 635], 5.00th=[ 652], 10.00th=[ 668], 20.00th=[ 693],
     | 30.00th=[ 709], 40.00th=[ 734], 50.00th=[ 750], 60.00th=[ 766],
     | 70.00th=[ 791], 80.00th=[ 824], 90.00th=[ 889], 95.00th=[ 955],
     | 99.00th=[12780], 99.50th=[17957], 99.90th=[20841], 99.95th=[24249],
     | 99.99th=[63177]
   bw ( KiB/s): min= 1536, max=86784, per=99.88%, avg=30256.93, stdev=25154.96, samples=690
   iops        : min= 12, max= 678, avg=236.38, stdev=196.52, samples=690
  lat (usec) : 750=35.52%, 1000=48.20%
  lat (msec) : 2=7.55%, 4=0.21%, 10=0.23%, 20=6.56%, 50=1.63%
  lat (msec) : 100=0.08%, 250=0.02%
  cpu : usr=0.26%, sys=2.26%, ctx=166008, majf=0, minf=9
  IO depths    : 1=100.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     issued rwts: total=82080,81760,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency : target=0, window=0, percentile=100.00%, depth=16

Run status group 0 (all jobs):
   READ: bw=29.7MiB/s (31.1MB/s), 29.7MiB/s-29.7MiB/s (31.1MB/s-31.1MB/s), io=10.0GiB (10.8GB), run=345472-345472msec
  WRITE: bw=29.6MiB/s (31.0MB/s), 29.6MiB/s-29.6MiB/s (31.0MB/s-31.0MB/s), io=9.98GiB (10.7GB), run=345472-345472msec

## DB Test

fio --name=zfs-rand \
    --directory=/SoloSSD/testbench \
    --rw=randrw \
    --bs=8k \
    --size=10G \
    --numjobs=4 \
    --iodepth=32 \
    --direct=1
zfs-rand: (g=0): rw=randrw, bs=(R) 8192B-8192B, (W) 8192B-8192B, (T) 8192B-8192B, ioengine=psync, iodepth=32
...
fio-3.39
Starting 4 processes
zfs-rand: Laying out IO file (1 file / 10240MiB)
zfs-rand: Laying out IO file (1 file / 10240MiB)
zfs-rand: Laying out IO file (1 file / 10240MiB)
zfs-rand: Laying out IO file (1 file / 10240MiB)
note: both iodepth >= 1 and synchronous I/O engine are selected, queue depth will be capped at 1
note: both iodepth >= 1 and synchronous I/O engine are selected, queue depth will be capped at 1
note: both iodepth >= 1 and synchronous I/O engine are selected, queue depth will be capped at 1
note: both iodepth >= 1 and synchronous I/O engine are selected, queue depth will be capped at 1
^Cbs: 4 (f=4): [m(4)][23.1%][r=368KiB/s,w=424KiB/s][r=46,w=53 IOPS][eta 06h:37m:54s]
fio: terminating on signal 2

zfs-rand: (groupid=0, jobs=1): err= 0: pid=1868499: Tue Jan 20 09:05:03 2026
  read: IOPS=21, BW=169KiB/s (173kB/s)(1183MiB/7179950msec)
    clat (usec): min=5, max=1113.1k, avg=24217.58, stdev=55059.57
     lat (usec): min=5, max=1113.1k, avg=24217.78, stdev=55059.59
    clat percentiles (usec):
     | 1.00th=[ 1991], 5.00th=[ 2900], 10.00th=[ 2966], 20.00th=[ 3064],
     | 30.00th=[ 3163], 40.00th=[ 3359], 50.00th=[ 3916], 60.00th=[ 6194],
     | 70.00th=[ 19792], 80.00th=[ 28181], 90.00th=[ 62653], 95.00th=[ 93848],
     | 99.00th=[278922], 99.50th=[413139], 99.90th=[557843], 99.95th=[650118],
     | 99.99th=[826278]
   bw ( KiB/s): min= 15, max= 1600, per=27.37%, avg=185.62, stdev=313.75, samples=13055
   iops        : min=    1, max= 200, avg=23.20, stdev=39.22, samples=13055
  write: IOPS=21, BW=169KiB/s (173kB/s)(1184MiB/7179950msec); 0 zone resets
    clat (usec): min=8, max=1087.7k, avg=23159.69, stdev=54537.75
     lat (usec): min=9, max=1087.7k, avg=23159.97, stdev=54537.77
    clat percentiles (usec):
     | 1.00th=[    35], 5.00th=[    49], 10.00th=[ 2933], 20.00th=[ 3032],
     | 30.00th=[ 3130], 40.00th=[ 3294], 50.00th=[ 3752], 60.00th=[ 5669],
     | 70.00th=[ 15270], 80.00th=[ 26084], 90.00th=[ 61604], 95.00th=[ 91751],
     | 99.00th=[283116], 99.50th=[413139], 99.90th=[557843], 99.95th=[633340],
     | 99.99th=[817890]
   bw ( KiB/s): min= 15, max= 1664, per=27.31%, avg=185.95, stdev=314.97, samples=13044
   iops        : min=    1, max= 208, avg=23.24, stdev=39.37, samples=13044
  lat (usec) : 10=0.03%, 20=0.29%, 50=2.43%, 100=0.30%, 250=0.04%
  lat (usec) : 500=0.01%, 750=0.01%, 1000=0.01%
  lat (msec) : 2=0.56%, 4=48.48%, 10=14.44%, 20=4.36%, 50=16.89%
  lat (msec) : 100=7.52%, 250=3.17%, 500=1.22%, 750=0.24%, 1000=0.02%
  lat (msec) : 2000=0.01%
  cpu : usr=0.03%, sys=0.23%, ctx=678918, majf=0, minf=11
  IO depths    : 1=100.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     issued rwts: total=151458,151605,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency : target=0, window=0, percentile=100.00%, depth=32
zfs-rand: (groupid=0, jobs=1): err= 0: pid=1868500: Tue Jan 20 09:05:03 2026
  read: IOPS=21, BW=169KiB/s (173kB/s)(1184MiB/7179950msec)
    clat (usec): min=5, max=980802, avg=24339.67, stdev=55279.05
     lat (usec): min=5, max=980802, avg=24339.91, stdev=55279.09
    clat percentiles (usec):
     | 1.00th=[ 1860], 5.00th=[ 2900], 10.00th=[ 2966], 20.00th=[ 3064],
     | 30.00th=[ 3163], 40.00th=[ 3359], 50.00th=[ 3916], 60.00th=[ 6194],
     | 70.00th=[ 19792], 80.00th=[ 28443], 90.00th=[ 62653], 95.00th=[ 94897],
     | 99.00th=[283116], 99.50th=[417334], 99.90th=[566232], 99.95th=[641729],
     | 99.99th=[792724]
   bw ( KiB/s): min= 15, max= 1600, per=27.37%, avg=185.15, stdev=313.76, samples=13099
   iops        : min=    1, max= 200, avg=23.14, stdev=39.22, samples=13099
  write: IOPS=21, BW=169KiB/s (174kB/s)(1188MiB/7179950msec); 0 zone resets
    clat (usec): min=8, max=996699, avg=22943.14, stdev=54209.21
     lat (usec): min=8, max=996699, avg=22943.46, stdev=54209.24
    clat percentiles (usec):
     | 1.00th=[    35], 5.00th=[    45], 10.00th=[ 2933], 20.00th=[ 3032],
     | 30.00th=[ 3130], 40.00th=[ 3261], 50.00th=[ 3720], 60.00th=[ 5669],
     | 70.00th=[ 15139], 80.00th=[ 26084], 90.00th=[ 61080], 95.00th=[ 90702],
     | 99.00th=[278922], 99.50th=[413139], 99.90th=[557843], 99.95th=[650118],
     | 99.99th=[817890]
   bw ( KiB/s): min= 15, max= 1776, per=27.46%, avg=186.70, stdev=317.94, samples=13034
   iops        : min=    1, max= 222, avg=23.33, stdev=39.74, samples=13034
  lat (usec) : 10=0.03%, 20=0.31%, 50=2.70%, 100=0.27%, 250=0.04%
  lat (usec) : 500=0.01%, 1000=0.01%
  lat (msec) : 2=0.54%, 4=48.44%, 10=14.31%, 20=4.38%, 50=16.84%
  lat (msec) : 100=7.48%, 250=3.18%, 500=1.21%, 750=0.24%, 1000=0.02%
  cpu : usr=0.03%, sys=0.23%, ctx=678650, majf=0, minf=11
  IO depths    : 1=100.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     issued rwts: total=151583,152098,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency : target=0, window=0, percentile=100.00%, depth=32
zfs-rand: (groupid=0, jobs=1): err= 0: pid=1868501: Tue Jan 20 09:05:03 2026
  read: IOPS=21, BW=169KiB/s (173kB/s)(1186MiB/7179951msec)
    clat (usec): min=5, max=1228.0k, avg=24414.13, stdev=55331.28
     lat (usec): min=5, max=1228.0k, avg=24414.33, stdev=55331.30
    clat percentiles (usec):
     | 1.00th=[ 1762], 5.00th=[ 2900], 10.00th=[ 2966], 20.00th=[ 3064],
     | 30.00th=[ 3163], 40.00th=[ 3359], 50.00th=[ 3916], 60.00th=[ 6259],
     | 70.00th=[ 19792], 80.00th=[ 28443], 90.00th=[ 62653], 95.00th=[ 96994],
     | 99.00th=[283116], 99.50th=[413139], 99.90th=[566232], 99.95th=[633340],
     | 99.99th=[750781]
   bw ( KiB/s): min= 15, max= 1616, per=27.37%, avg=185.46, stdev=314.16, samples=13102
   iops        : min=    1, max= 202, avg=23.18, stdev=39.27, samples=13102
  write: IOPS=21, BW=169KiB/s (173kB/s)(1184MiB/7179951msec); 0 zone resets
    clat (usec): min=8, max=1528.0k, avg=22897.01, stdev=54660.84
     lat (usec): min=8, max=1528.0k, avg=22897.29, stdev=54660.87
    clat percentiles (usec):
     | 1.00th=[    35], 5.00th=[    46], 10.00th=[ 2933], 20.00th=[ 3032],
     | 30.00th=[ 3130], 40.00th=[ 3261], 50.00th=[ 3720], 60.00th=[ 5669],
     | 70.00th=[ 15139], 80.00th=[ 25822], 90.00th=[ 61080], 95.00th=[ 89654],
     | 99.00th=[278922], 99.50th=[413139], 99.90th=[566232], 99.95th=[683672],
     | 99.99th=[834667]
   bw ( KiB/s): min= 15, max= 1680, per=27.46%, avg=186.85, stdev=315.79, samples=12983
   iops        : min=    1, max= 210, avg=23.35, stdev=39.47, samples=12983
  lat (usec) : 10=0.02%, 20=0.32%, 50=2.61%, 100=0.29%, 250=0.03%
  lat (usec) : 500=0.01%, 1000=0.01%
  lat (msec) : 2=0.52%, 4=48.52%, 10=14.30%, 20=4.36%, 50=16.86%
  lat (msec) : 100=7.49%, 250=3.18%, 500=1.20%, 750=0.25%, 1000=0.01%
  lat (msec) : 2000=0.01%
  cpu : usr=0.03%, sys=0.23%, ctx=679012, majf=0, minf=9
  IO depths    : 1=100.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     issued rwts: total=151864,151612,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency : target=0, window=0, percentile=100.00%, depth=32
zfs-rand: (groupid=0, jobs=1): err= 0: pid=1868502: Tue Jan 20 09:05:03 2026
  read: IOPS=21, BW=169KiB/s (173kB/s)(1186MiB/7179952msec)
    clat (usec): min=5, max=1154.8k, avg=24195.18, stdev=54868.11
     lat (usec): min=5, max=1154.8k, avg=24195.37, stdev=54868.13
    clat percentiles (usec):
     | 1.00th=[ 1565], 5.00th=[ 2900], 10.00th=[ 2966], 20.00th=[ 3032],
     | 30.00th=[ 3163], 40.00th=[ 3359], 50.00th=[ 3916], 60.00th=[ 6194],
     | 70.00th=[ 19792], 80.00th=[ 28181], 90.00th=[ 63177], 95.00th=[ 93848],
     | 99.00th=[278922], 99.50th=[413139], 99.90th=[557843], 99.95th=[675283],
     | 99.99th=[817890]
   bw ( KiB/s): min= 13, max= 1664, per=27.37%, avg=185.97, stdev=314.86, samples=13056
   iops        : min=    1, max= 208, avg=23.24, stdev=39.35, samples=13056
  write: IOPS=21, BW=170KiB/s (174kB/s)(1192MiB/7179952msec); 0 zone resets
    clat (usec): min=8, max=1095.1k, avg=22982.42, stdev=54328.60
     lat (usec): min=8, max=1095.1k, avg=22982.70, stdev=54328.62
    clat percentiles (usec):
     | 1.00th=[    34], 5.00th=[    44], 10.00th=[ 2933], 20.00th=[ 3032],
     | 30.00th=[ 3130], 40.00th=[ 3261], 50.00th=[ 3720], 60.00th=[ 5604],
     | 70.00th=[ 15008], 80.00th=[ 25560], 90.00th=[ 61080], 95.00th=[ 91751],
     | 99.00th=[278922], 99.50th=[413139], 99.90th=[557843], 99.95th=[650118],
     | 99.99th=[801113]
   bw ( KiB/s): min= 15, max= 1632, per=27.46%, avg=186.48, stdev=317.16, samples=13095
   iops        : min=    1, max= 204, avg=23.31, stdev=39.64, samples=13095
  lat (usec) : 10=0.04%, 20=0.39%, 50=2.79%, 100=0.30%, 250=0.03%
  lat (usec) : 1000=0.01%
  lat (msec) : 2=0.53%, 4=48.35%, 10=14.27%, 20=4.40%, 50=16.70%
  lat (msec) : 100=7.55%, 250=3.19%, 500=1.20%, 750=0.24%, 1000=0.01%
  lat (msec) : 2000=0.01%
  cpu : usr=0.03%, sys=0.23%, ctx=678977, majf=0, minf=9
  IO depths    : 1=100.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     issued rwts: total=151745,152620,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency : target=0, window=0, percentile=100.00%, depth=32

Run status group 0 (all jobs):
   READ: bw=676KiB/s (692kB/s), 169KiB/s-169KiB/s (173kB/s-173kB/s), io=4739MiB (4970MB), run=7179950-7179952msec
  WRITE: bw=677KiB/s (694kB/s), 169KiB/s-170KiB/s (173kB/s-174kB/s), io=4749MiB (4980MB), run=7179950-7179952msec
