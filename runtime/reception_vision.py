"""Local face identity adapter for CHATGPT's TAICaptureSource.

JSON-lines over stdin/stdout. No network, no camera ownership, no LLM identity
guessing. Frames come from the native Pascal camera component. Enrollment is
explicit; unknown people are never enrolled automatically.
"""
import argparse
import json
from pathlib import Path
import re
import sys


def choose_identity(scores, threshold=0.5, margin=0.08):
    ordered = sorted(scores.items(), key=lambda item: item[1], reverse=True)
    if not ordered or ordered[0][1] < threshold:
        return "", 0.0
    if len(ordered) > 1 and ordered[0][1] - ordered[1][1] < margin:
        return "", ordered[0][1]
    return ordered[0]


class Vision:
    def __init__(self, models, data):
        import cv2
        import numpy as np
        self.cv, self.np = cv2, np
        self.data = Path(data)
        self.data.mkdir(parents=True, exist_ok=True)
        self.registry = self.data / "people.json"
        self.people = json.loads(self.registry.read_text(encoding="utf-8")) if self.registry.exists() else {}
        self.detector = cv2.FaceDetectorYN.create(str(Path(models) / "yunet.onnx"), "", (640, 480), 0.9)
        self.recognizer = cv2.FaceRecognizerSF.create(str(Path(models) / "sface.onnx"), "")

    def feature(self, image, face):
        aligned = self.recognizer.alignCrop(image, face)
        return self.recognizer.feature(aligned).flatten()

    def process(self, request):
        cv, np = self.cv, self.np
        image = cv.imdecode(np.fromfile(request["frame"], dtype=np.uint8), cv.IMREAD_COLOR)
        if image is None:
            raise ValueError("Nao foi possivel ler o quadro da camera")
        self.detector.setInputSize((image.shape[1], image.shape[0]))
        _, faces = self.detector.detect(image)
        count = 0 if faces is None else len(faces)
        result = {"ok": True, "count": count, "id": "", "name": "", "score": 0.0}
        if request.get("command") == "enroll":
            if count != 1:
                raise ValueError("Cadastro exige exatamente uma pessoa diante da camera")
            person_id = request.get("id", "")
            if not re.fullmatch(r"[A-Za-z0-9_-]{1,64}", person_id):
                raise ValueError("Identificador deve conter apenas letras, numeros, _ ou -")
            name = request.get("name", "").strip()
            if not name:
                raise ValueError("Informe o nome da pessoa")
            person = self.people.setdefault(person_id, {"samples": []})
            person.update(name=name, role=request.get("role", ""), bio=request.get("bio", ""))
            person["samples"].append(self.feature(image, faces[0]).tolist())
            person["samples"] = person["samples"][-10:]
            temp = self.registry.with_suffix(".tmp")
            temp.write_text(json.dumps(self.people, ensure_ascii=False), encoding="utf-8")
            temp.replace(self.registry)
            return {"ok": True, "enrolled": True, "name": name, "samples": len(person["samples"])}
        # Several visible faces cannot establish who is speaking. Never select
        # the largest face and accidentally expose that person's conversation.
        if count != 1:
            return result
        feature = self.feature(image, faces[0]).reshape(1, -1)
        scores = {}
        for person_id, person in self.people.items():
            scores[person_id] = max((float(self.recognizer.match(
                feature, np.asarray(sample, dtype=np.float32).reshape(1, -1),
                cv.FaceRecognizerSF_FR_COSINE)) for sample in person["samples"]), default=-1)
        person_id, score = choose_identity(scores)
        if person_id:
            person = self.people[person_id]
            result.update(id=person_id, name=person["name"], role=person.get("role", ""),
                          bio=person.get("bio", ""), score=score)
        return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--models", required=True)
    parser.add_argument("--data", required=True)
    args = parser.parse_args()
    try:
        vision = Vision(args.models, args.data)
        print(json.dumps({"ok": True, "ready": True}), flush=True)
    except Exception as exc:
        print(json.dumps({"ok": False, "error": str(exc)}), flush=True)
        return 1
    for line in sys.stdin:
        try:
            response = vision.process(json.loads(line))
        except Exception as exc:
            response = {"ok": False, "error": str(exc)}
        print(json.dumps(response, ensure_ascii=True), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
