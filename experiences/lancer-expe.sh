
export OMP_NUM_THREADS

ITE=$(seq 10) # nombre de mesures
  
THREADS=$(seq 2 2 24) # nombre de threads
ITERATIONS=("10" "100" "1000" "10000")
VERSIONS=("2" "3" "4")
SIZES=("256" "512" "1024" "4096")

PARAM="-n -a" # parametres commun à toutes les executions 

execute (){
cd ../
EXE="./prog $* $PARAM"
OUTPUT="$(echo $EXE | tr -d ' ')"
for nb in $ITE; 
do 
	for OMP_NUM_THREADS in $THREADS; 
	do 
		echo "iteration $nb, thread $OMP_NUM_THREADS"
		echo -n "$OMP_NUM_THREADS " >> $OUTPUT ;
		$EXE 2>> experiences/$OUTPUT; 
	done; 
done
cd experiences/
}

for v in ${VERSIONS[@]};
do
    for it in ${ITERATIONS[@]};
    do
		for size in ${SIZES[@]};
		do

			echo "First size $size, it $it"
		        execute -v $v -s $size -i $it
			echo "second size $size, it $it"
	        	execute -v $v -s $size -i $it
		done
    done
done




