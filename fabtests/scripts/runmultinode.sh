#!/bin/bash


echo "@=$@"

Options=$(getopt --options h:,n:,p:,I:,C: \
		  		--longoptions hosts:,processes-per-node:,provider:,capability:\
				  ,iterations:,cleanup,help \
				--"$@")

eval set -- "$Options"

hosts=[]
ppn=1
iterations=1
pattern=""
cleanup=false
help=false

while true; do
	case "$1" in
		-h|--hosts)
			IFS=',' read -r -a hosts <<< "$2"; shift 2 ;;
		-n|--processes-per-node) 
			ppn=$2; shift 2 ;;
		-p|--provider)
			provider="$2"; shift 2 ;;
		-I|--iterations)
			iterations=$2; shift 2 ;;
		-C|--capability)
			capability="$2"; shift 2 ;;
		--cleanup)
			cleanup=true; shift ;;
		--help) 
			help=true; shift ;;
		--)
			shift; break ;;
	esac
done

if $help ; then
	echo "Run the multinode test suite on the nodes provided for many procceses" 
	echo "Options"
	echo "\t -h,--hosts list of host names to run thests on"
	echo "\t -n,--processes-per-node number of processes to be run on each node.\
					Total number of fi_mulinode tests run will be n*number of hosts"
	echo "\t -p,--provider libfabric provider to run the multinode tests on"
	echo "\t -C,--cabability multinode cabability to use (rma or default: msg)"
	echo "\t -I,-- iterations number of iterations for the multinode test \
				to run each pattern on"
	echo "\t --cleanup end straggling processes. Does not rerun tests"
	echo "\t --help show this message"
	exit 1
fi
		
num_hosts=${#hosts[@]}
ranks=$(($num_hosts*$ppn))
server=${hosts[0]}
start_server=0
output="multinode_server_$ranks.out"

cmd="fi_multinode -n $ranks -s $server -p '$provider' -C $capability -I $iterations"
echo $cmd

if ! $cleanup ; then
  
	for node in "${hosts[@]}"; do
		for i in $(seq 1 $ppn); do
			if [ $start_server -eq 0 ]; then
				echo STARTING SERVER
				ssh $node $cmd &> $output &
				server_pid=$!
				start_server=1
				sleep .5
			else
				ssh $node $cmd &> /dev/null &
			fi
		done
	done

	echo Wait for processes to finish...
	wait $server_pid
fi

echo Cleaning up
  
for node in "${hosts[@]}"; do
	ssh $node "ps -eo comm,pid | grep '^fi_multinode' | awk '{print \$2}' | xargs kill -9" >& /dev/null
done;
