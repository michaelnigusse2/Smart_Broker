#!/system/bin/sh
# Addis Scribe trial on an Android device: speed, peak RAM and transcripts.
# Pushed to /data/local/tmp/scribe/run.sh by tool/emu_bridge.bat ("scribe phone").
cd "$(dirname "$0")" || exit 1
export LD_LIBRARY_PATH=.
M=addis-scribe-rnnt-q5_k.gguf

echo "== device"
echo "model: $(getprop ro.product.model)  soc: $(getprop ro.soc.model) $(getprop ro.board.platform)  android: $(getprop ro.build.version.release)  cpus: $(nproc)"
grep -E "MemTotal|MemAvailable" /proc/meminfo
./nemo-speech doctor

if [ ! -f "$M" ]; then echo "no model pushed; runtime check only"; exit 0; fi

# Runs "$@" and prints its peak resident memory (VmHWM) when it exits.
peak() {
  "$@" &
  P=$!
  H=0
  while kill -0 $P 2>/dev/null; do
    V=$(grep VmHWM /proc/$P/status 2>/dev/null | tr -s ' \t' ' ' | cut -d' ' -f2)
    [ -n "$V" ] && H=$V
    sleep 0.3
  done
  wait $P
  echo "exit=$? peak_rss_mb=$((H / 1024))"
}

for T in 8 4; do
  echo "== bench offline, $T threads (jfk.wav, 11 s)"
  peak ./nemo-speech bench asr jfk.wav --model $M -l am-ET -c 1 -n 3 --asr.backend.threads $T
done
echo "== bench stream (160 ms chunks), 4 threads"
peak ./nemo-speech bench asr jfk.wav --model $M -l am-ET -c 1 -n 2 --mode stream --asr.backend.threads 4

# The voice notes in wav/: real-time factor over the whole set, transcripts in out/.
if ls wav/*.wav >/dev/null 2>&1; then
  echo "== your notes, streaming (0.32 s chunks), 4 threads"
  peak ./nemo-speech bench asr wav --model $M -l am-ET -c 1 -n 1 --mode stream --chunk-ms 320 --asr.backend.threads 4 --save out/stream
  echo "== your notes, offline, 4 threads"
  peak ./nemo-speech bench asr wav --model $M -l am-ET -c 1 -n 1 --asr.backend.threads 4 --save out/offline
  for F in out/stream/*; do echo "-- $F"; cat "$F"; echo; done
fi
echo "== done"
