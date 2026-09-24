"""Download public OpenCV model weights. Run with the reception Python runtime."""
from pathlib import Path
import urllib.request

MODELS = {
    "yunet.onnx": "https://media.githubusercontent.com/media/opencv/opencv_zoo/main/models/face_detection_yunet/face_detection_yunet_2023mar.onnx",
    "sface.onnx": "https://media.githubusercontent.com/media/opencv/opencv_zoo/main/models/face_recognition_sface/face_recognition_sface_2021dec.onnx",
}

if __name__ == "__main__":
    target = Path(__file__).parent / "models"
    target.mkdir(exist_ok=True)
    for name, url in MODELS.items():
        dest = target / name
        if dest.exists():
            print(f"Already present: {dest}")
            continue
        temporary = dest.with_suffix(".download")
        urllib.request.urlretrieve(url, temporary)
        if temporary.stat().st_size < 100_000:
            raise RuntimeError(f"Invalid model download: {name}")
        temporary.replace(dest)
        print(f"Downloaded: {dest}")
