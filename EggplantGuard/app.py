"""
EggplantGuard — Streamlit Community Cloud entrypoint
-----------------------------------------------------
Loads the Teachable Machine model from its hosted URL at runtime.
"""

import json
import os
import tempfile

import numpy as np
import requests
import streamlit as st
from PIL import Image

# ── Model URL & Confidence Threshold ─────────────────────────────────────────
MODEL_URL = "https://teachablemachine.withgoogle.com/models/jq8kSVI_-/"
CONFIDENCE_THRESHOLD = 0.65  # Minimum confidence required to accept as valid eggplant

# ── Farming guidance for each class ──────────────────────────────────────────
GUIDANCE = {
    "Healthy Leaf": {
        "icon": "🌿",
        "description": "The image most closely matches the model's healthy-leaf examples.",
        "recommendation": (
            "Continue routine crop monitoring. Check leaves regularly and keep plants "
            "well cared for. This prediction is a visual screening result, not proof "
            "that the plant is disease-free."
        ),
    },
    "Leaf Miner Damage": {
        "icon": "🍃",
        "description": "The image most closely matches the model's leaf-miner-damage examples.",
        "recommendation": (
            "Inspect nearby leaves for similar winding trails. Remove heavily affected "
            "leaves when appropriate and dispose of them responsibly. Ask a local "
            "agricultural technician for advice if damage spreads."
        ),
    },
    "Fresh/Market-Ready Fruit": {
        "icon": "🍆",
        "description": "The image most closely matches the model's fresh/market-ready fruit examples.",
        "recommendation": (
            "Check firmness, size, skin condition, and local market standards before "
            "harvesting. The AI result alone cannot confirm freshness or food safety."
        ),
    },
    "Damaged/Borer-Infested Fruit": {
        "icon": "⚠️",
        "description": "The image most closely matches the model's damaged/borer-infested fruit examples.",
        "recommendation": (
            "Inspect the fruit for holes, frass, and soft or rotting areas. Separate "
            "visibly damaged fruit and check nearby plants. Seek local agricultural "
            "guidance to confirm the cause before choosing a control method."
        ),
    },
}


# ── Model loading (cached for the app session) ────────────────────────────────
@st.cache_resource(show_spinner="Loading AI model — please wait…")
def load_model():
    """
    Downloads model.json, weight shards, and metadata.json from the hosted
    Teachable Machine URL, then loads the Keras model via tensorflowjs.
    Returns (model, labels, image_size).
    """
    import tensorflowjs as tfjs  # imported here so cold-import cost is deferred

    tmpdir = tempfile.mkdtemp()

    # 1. Fetch model.json
    model_json_resp = requests.get(MODEL_URL + "model.json", timeout=30)
    model_json_resp.raise_for_status()
    model_json = model_json_resp.json()

    with open(os.path.join(tmpdir, "model.json"), "w") as fh:
        json.dump(model_json, fh)

    # 2. Fetch weight shards listed in weightsManifest
    for group in model_json.get("weightsManifest", []):
        for shard_path in group.get("paths", []):
            r = requests.get(MODEL_URL + shard_path, timeout=60)
            r.raise_for_status()
            shard_file = os.path.join(tmpdir, shard_path)
            os.makedirs(os.path.dirname(shard_file), exist_ok=True)
            with open(shard_file, "wb") as fh:
                fh.write(r.content)

    # 3. Load the Keras model from the downloaded TF.js files
    model = tfjs.converters.load_keras_model(os.path.join(tmpdir, "model.json"))

    # 4. Fetch metadata for class labels and input image size
    meta_resp = requests.get(MODEL_URL + "metadata.json", timeout=30)
    meta_resp.raise_for_status()
    metadata = meta_resp.json()

    labels = metadata.get("labels", [])
    image_size = int(metadata.get("imageSize", 224))

    return model, labels, image_size


# ── Image helpers & validation ───────────────────────────────────────────────
def preprocess(image: Image.Image, image_size: int) -> np.ndarray:
    """Center-crop and normalize like Teachable Machine's browser image pipeline."""
    img = image.convert("RGB")
    width, height = img.size
    crop_size = min(width, height)
    left = (width - crop_size) // 2
    top = (height - crop_size) // 2
    img = img.crop((left, top, left + crop_size, top + crop_size))
    img = img.resize((image_size, image_size), Image.Resampling.BILINEAR)
    arr = np.asarray(img, dtype=np.float32) / 127.0 - 1.0
    return np.expand_dims(arr, axis=0)  # shape: (1, H, W, 3)


def is_recognized_eggplant_class(label: str) -> bool:
    """Check if the predicted label corresponds to an eggplant category."""
    name = (label or "").lower()
    if any(
        kw in name
        for kw in [
            "not eggplant",
            "non-eggplant",
            "not_eggplant",
            "invalid",
            "other",
            "unknown",
            "background",
        ]
    ):
        return False
    is_leaf = "leaf" in name
    is_fruit = "fruit" in name or "eggplant" in name or "borer" in name
    return is_leaf or is_fruit


def check_eggplant_features(image: Image.Image) -> bool:
    """Check if the image contains typical eggplant leaf or fruit visual features."""
    try:
        small = image.convert("RGB").resize((64, 64))
        arr = np.array(small, dtype=np.float32) / 255.0
        r, g, b = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2]

        max_c = np.maximum(np.maximum(r, g), b)
        min_c = np.minimum(np.minimum(r, g), b)
        delta = max_c - min_c

        h = np.zeros_like(max_c)
        mask_r = (max_c == r) & (delta != 0)
        mask_g = (max_c == g) & (delta != 0)
        mask_b = (max_c == b) & (delta != 0)

        h[mask_r] = ((g[mask_r] - b[mask_r]) / (delta[mask_r] + 1e-7)) % 6
        h[mask_g] = ((b[mask_g] - r[mask_g]) / (delta[mask_g] + 1e-7)) + 2
        h[mask_b] = ((r[mask_b] - g[mask_b]) / (delta[mask_b] + 1e-7)) + 4
        h = h * 60.0
        h[h < 0] += 360.0

        s = np.where(max_c == 0, 0, delta / (max_c + 1e-7))
        v = max_c

        green_leaf = (h >= 55) & (h <= 170) & (s >= 0.15) & (v >= 0.15)
        leaf_damage = (h >= 25) & (h < 55) & (s >= 0.18) & (v >= 0.18)
        purple_fruit = (h >= 250) & (h <= 335) & (s >= 0.12) & (v >= 0.08)
        dark_fruit = (v < 0.22) & (max_c > 0.04) & ((b >= g) | (r >= g))

        matched = green_leaf | leaf_damage | purple_fruit | dark_fruit
        ratio = float(np.mean(matched))
        return ratio >= 0.06
    except Exception:
        return True


def classify(image: Image.Image, model, labels, image_size):
    """Return predictions sorted by probability descending."""
    arr = preprocess(image, image_size)
    preds = model.predict(arr, verbose=0)[0]
    results = [(labels[i], float(preds[i])) for i in range(len(labels))]
    results.sort(key=lambda x: x[1], reverse=True)
    return results


# ── Streamlit page ────────────────────────────────────────────────────────────
st.set_page_config(
    page_title="EggplantGuard | Eggplant Health & Fruit Quality",
    page_icon="🍆",
    layout="centered",
)

# Header
st.markdown(
    """
    <div style="display:flex;align-items:center;gap:12px;margin-bottom:0.25rem">
      <span style="font-size:2.4rem">🍆</span>
      <div>
        <h1 style="margin:0;line-height:1.1">EggplantGuard</h1>
        <p style="margin:0;color:#5a7d65;font-size:0.82rem;letter-spacing:.08em">
          SMART CROP CHECK &nbsp;·&nbsp; AI CLASSIFIER
        </p>
      </div>
    </div>
    """,
    unsafe_allow_html=True,
)
st.divider()

# Hero copy
st.markdown(
    """
    ### Healthier eggplants start with a closer look.
    Upload a photo or use your camera to check an eggplant leaf or fruit
    with the trained AI model.

    > ✦ **Educational screening tool — not a certified diagnosis.**
    """
)

# ── Load model ────────────────────────────────────────────────────────────────
try:
    model, labels, image_size = load_model()
    st.success("✅ AI model loaded and ready.")
except Exception as exc:
    st.error(f"Could not load the AI model: {exc}")
    st.stop()

st.divider()

# ── Step 1: Image input ───────────────────────────────────────────────────────
st.markdown("### Step 01 — Choose your sample")

tab_upload, tab_camera = st.tabs(["📤 Upload an image", "📷 Use your camera"])

selected_image: Image.Image | None = None
image_label = ""

with tab_upload:
    st.markdown("Choose a clear **JPG, JPEG, or PNG** photo of one leaf or one fruit.")
    uploaded = st.file_uploader(
        "Select image file",
        type=["jpg", "jpeg", "png"],
        label_visibility="collapsed",
    )
    if uploaded:
        selected_image = Image.open(uploaded)
        image_label = uploaded.name

with tab_camera:
    st.markdown("Allow camera access, position the sample, then capture a snapshot.")
    camera_snap = st.camera_input("Take a photo", label_visibility="collapsed")
    if camera_snap:
        selected_image = Image.open(camera_snap)
        image_label = "Webcam snapshot"

# ── Step 2: Preview + classify ────────────────────────────────────────────────
if selected_image is not None:
    st.divider()
    st.markdown("### Step 02 — Image preview")
    st.image(selected_image, caption=image_label, use_column_width=True)

    st.markdown(
        "For best results, show one eggplant leaf or fruit clearly. "
        "Avoid blurry images and busy backgrounds."
    )

    if st.button("✦ Classify image", type="primary", use_container_width=True):
        with st.spinner("Analysing image…"):
            results = classify(selected_image, model, labels, image_size)

        top_label, top_prob = results[0]
        is_eggplant_class = is_recognized_eggplant_class(top_label)
        has_sufficient_confidence = top_prob >= CONFIDENCE_THRESHOLD
        has_visual_features = check_eggplant_features(selected_image)

        is_valid = is_eggplant_class and has_sufficient_confidence and has_visual_features

        st.divider()
        st.markdown("### Step 03 — Classification result")

        if not is_valid:
            reason_text = "The uploaded sample was not recognized as an eggplant leaf or fruit."
            if not is_eggplant_class:
                reason_text = "The detected category is not an eggplant leaf or fruit."
            elif not has_visual_features:
                reason_text = "The image lacks typical eggplant leaf or fruit visual features."
            elif not has_sufficient_confidence:
                reason_text = (
                    f"Confidence is too low ({top_prob * 100:.1f}% < 70%) to confirm this is an eggplant."
                )

            col_icon, col_text = st.columns([1, 4])
            with col_icon:
                st.markdown(
                    "<div style='font-size:3rem;text-align:center;padding-top:0.5rem'>🚫</div>",
                    unsafe_allow_html=True,
                )
            with col_text:
                st.caption("VERIFICATION FAILED")
                st.markdown("#### Invalid: Not an Eggplant")
                st.markdown(reason_text)

            st.progress(top_prob, text=f"Top Match Confidence: {top_prob * 100:.1f}%")

            st.error(
                "**Why is this invalid?**\n\n"
                "EggplantGuard only screens eggplant leaves and fruits. The submitted image is either "
                "not an eggplant, has low classification confidence (< 70%), or lacks typical plant features. "
                "Please upload a clear, well-lit photo of an eggplant leaf or fruit."
            )
        else:
            info = GUIDANCE.get(
                top_label,
                {
                    "icon": "🔎",
                    "description": "The model selected the closest class in its training data.",
                    "recommendation": (
                        "Review the image and compare it with the training examples. "
                        "This AI result is an educational estimate, not a confirmed diagnosis."
                    ),
                },
            )

            col_icon, col_text = st.columns([1, 4])
            with col_icon:
                st.markdown(
                    f"<div style='font-size:3rem;text-align:center;padding-top:0.5rem'>"
                    f"{info['icon']}</div>",
                    unsafe_allow_html=True,
                )
            with col_text:
                st.caption("TOP PREDICTION")
                st.markdown(f"#### {top_label}")
                st.markdown(info["description"])

            st.progress(top_prob, text=f"Confidence: {top_prob * 100:.1f}%")

            st.info(f"**Recommended next step**\n\n{info['recommendation']}")

        with st.expander("All prediction scores"):
            for lbl, prob in results:
                st.progress(prob, text=f"{lbl}: {prob * 100:.1f}%")

        st.caption(
            "⚠️ **Important:** AI predictions can be wrong. Confirm unusual symptoms "
            "with an agricultural expert. Do not rely on this prototype alone for "
            "treatment decisions."
        )

# ── Classes reference ─────────────────────────────────────────────────────────
st.divider()
st.markdown("### What the model can recognise")
st.markdown("**Four trained categories:**")

class_cols = st.columns(4)
CLASSES = [
    ("🌿", "Healthy Leaf", "Leaf resembling healthy training examples."),
    ("🍃", "Leaf Miner Damage", "Leaf resembling leaf-miner damage examples."),
    ("🍆", "Fresh/Market-Ready Fruit", "Fruit resembling fresh, market-ready examples."),
    ("⚠️", "Damaged/Borer-Infested Fruit", "Fruit resembling damaged fruit examples."),
]
for col, (icon, name, desc) in zip(class_cols, CLASSES):
    with col:
        st.markdown(f"**{icon}**\n\n**{name}**\n\n{desc}")

st.divider()
st.caption("**EggplantGuard** · AI-assisted crop screening for learning and demonstration")
