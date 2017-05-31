
export OMP_NUM_THREADS

ITE=$(seq 10) # nombre de mesures
  
THREADS=$(seq 2 2 24) # nombre de threads
SIZE=$1
ITERATIONS=(10 100 1000 10000)
VERSIONS=(0 1 2 3 4 6 7)

PARAM="-n -a" # parametres commun à toutes les executions 

execute (){
EXE="../prog $* $PARAM"
OUTPUT="$(echo $EXE | tr -d ' ')"
for nb in $ITE; do for OMP_NUM_THREADS in $THREADS; do  echo -n "$OMP_NUM_THREADS " >> $OUTPUT ; $EXE 2>> $OUTPUT; done; done
}

for v in $VERSIONS;
do
    for it in $ITERATIONS;
    do
        execute -v $v -s $SIZE -i $it
        execute -v $v -s $SIZE -i $it
    done
done




