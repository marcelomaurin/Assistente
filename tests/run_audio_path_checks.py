"""Play a local silent WAV beyond the MCI path limit without changing its bytes."""
from pathlib import Path
import hashlib,subprocess,sys,tempfile,wave
with tempfile.TemporaryDirectory(prefix='assistente-audio-path-') as directory:
    root=Path(directory)/('long-directory-'*4)/('another-directory-'*4)
    root.mkdir(parents=True);audio=root/'audio-with-a-long-name.wav'
    with wave.open(str(audio),'wb') as wav:
        wav.setnchannels(1);wav.setsampwidth(2);wav.setframerate(16000);wav.writeframes(b'\0'*16000)
    assert len(str(audio))>200
    before=hashlib.sha256(audio.read_bytes()).digest()
    p=subprocess.run([str(Path(sys.argv[1]).resolve()),str(audio)],capture_output=True,timeout=10)
    assert p.returncode==0,(p.stdout,p.stderr)
    assert before==hashlib.sha256(audio.read_bytes()).digest()
    print(p.stdout.decode('utf-8',errors='replace').strip())
