"""Addis Scribe accuracy check on your own voice notes.

build_logs/scribe/audio/<name>.<any> + <name>.txt (what was said)
  -> build_logs/scribe/wav/<name>.wav (16 kHz mono, also pushed to the phone)
Transcribes each with the NeMo-Speech CLI and reports WER/CER, raw and with
the usual Amharic spelling normalisation (homophone letters, punctuation).
Usage: python3 tool/scribe/eval_notes.py <nemo-speech binary> <model.gguf> [threads]
"""
import json, os, re, subprocess, sys, time, unicodedata

HERE = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'build_logs', 'scribe')
AUDIO, WAV, OUT = (os.path.join(HERE, d) for d in ('audio', 'wav', 'out_pc'))

def homophones(text):
    out = []
    for ch in text:
        c = ord(ch)
        for src, dst in ((0x1210, 0x1200), (0x1280, 0x1200), (0x1220, 0x1230), (0x12D0, 0x12A0), (0x1340, 0x1338)):
            if src <= c < src + 8:
                c = dst + (c - src)
                break
        if c in (0x1203, 0x12A3):  # ሃ -> ሀ, ኣ -> አ (spelled both ways)
            c -= 3
        out.append(chr(c))
    return ''.join(out)

def words(text, normalise):
    text = unicodedata.normalize('NFC', text)
    if normalise:
        text = homophones(text)
        text = re.sub(r'[፠-፨.,!?;:"\'()\[\]«»“”‘’\-–—/]', ' ', text).lower()
    return text.split()

def edit_distance(a, b):
    prev = list(range(len(b) + 1))
    for i, x in enumerate(a, 1):
        cur = [i]
        for j, y in enumerate(b, 1):
            cur.append(min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (x != y)))
        prev = cur
    return prev[-1]

def rates(ref, hyp, normalise):
    r, h = words(ref, normalise), words(hyp, normalise)
    wer = edit_distance(r, h) / max(len(r), 1)
    rc, hc = list(''.join(r)), list(''.join(h))
    cer = edit_distance(rc, hc) / max(len(rc), 1)
    return wer, cer, len(r)

def duration(path):
    out = subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', path],
                         capture_output=True, text=True).stdout.strip()
    return float(out or 0)

def main():
    binary, model = sys.argv[1], sys.argv[2]
    threads = sys.argv[3] if len(sys.argv) > 3 else '0'
    os.makedirs(WAV, exist_ok=True); os.makedirs(OUT, exist_ok=True)
    rows = []
    for name in sorted(os.listdir(AUDIO)):
        stem, ext = os.path.splitext(name)
        if ext.lower() == '.txt' or name.startswith('.'):
            continue
        ref_path = os.path.join(AUDIO, stem + '.txt')
        wav = os.path.join(WAV, stem + '.wav')
        subprocess.run(['ffmpeg', '-y', '-v', 'error', '-i', os.path.join(AUDIO, name), '-ac', '1', '-ar', '16000',
                        '-c:a', 'pcm_s16le', wav], check=True)
        ref = open(ref_path, encoding='utf-8-sig').read().strip() if os.path.exists(ref_path) else None
        # Streaming is how the model was trained and benchmarked; offline is
        # one pass over the whole note. Score both.
        for mode, extra in (('stream', ['--stream']), ('offline', [])):
            hyp_path = os.path.join(OUT, f'{stem}.{mode}.txt')
            cmd = [binary, 'transcribe', wav, '--model', model, '-l', 'am-ET', '-o', hyp_path, '--force'] + extra
            if threads != '0':
                cmd += ['--asr.backend.threads', threads]
            t0 = time.time(); subprocess.run(cmd, check=True, capture_output=True); secs = time.time() - t0
            hyp = open(hyp_path, encoding='utf-8').read().strip()
            row = {'file': stem, 'mode': mode, 'audio_s': round(duration(wav), 1), 'run_s': round(secs, 1), 'hyp': hyp}
            if ref is not None:
                row['ref'] = ref
                for label, norm in (('raw', False), ('norm', True)):
                    w, c, n = rates(ref, hyp, norm)
                    row[f'wer_{label}'], row[f'cer_{label}'], row['ref_words'] = round(w * 100, 1), round(c * 100, 1), n
            rows.append(row)
            print(json.dumps(row, ensure_ascii=False))
    for mode in ('stream', 'offline'):
        scored = [r for r in rows if r['mode'] == mode and 'wer_norm' in r]
        if not scored:
            continue
        tot = sum(r['ref_words'] for r in scored)
        speed = sum(r['audio_s'] for r in scored) / max(sum(r['run_s'] for r in scored), 0.1)
        parts = [f'{k} {sum(r[k] * r["ref_words"] for r in scored) / tot:.1f}%' for k in ('wer_raw', 'cer_raw', 'wer_norm', 'cer_norm')]
        print(f'{mode}: ' + ', '.join(parts) + f' ({len(scored)} notes, word-weighted; {speed:.1f}x real time incl. load)')
    json.dump(rows, open(os.path.join(HERE, 'results_pc.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)

if __name__ == '__main__':
    main()
