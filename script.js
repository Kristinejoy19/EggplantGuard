// EggplantGuard - JavaScript matching the IDs in index.html
// Uses the Teachable Machine model URL supplied in the uploaded script.js.
const MODEL_URL = "https://teachablemachine.withgoogle.com/models/jq8kSVI_-/";

// Minimum confidence required to accept a prediction as a valid eggplant sample
const CONFIDENCE_THRESHOLD = 0.65;

let model = null;
let modelLoading = null;
let cameraStream = null;
let selectedImage = null;

const imageInput = document.getElementById("imageInput");
const imagePreview = document.getElementById("imagePreview");
const imageStatus = document.getElementById("imageStatus");
const previewWrap = document.getElementById("previewWrap");
const emptyPreview = document.getElementById("emptyPreview");
const previewViewfinder = document.getElementById("previewViewfinder");
const previewBadge = document.getElementById("previewBadge");
const previewZoomBtn = document.getElementById("previewZoomBtn");
const zoomIcon = document.getElementById("zoomIcon");

const startCameraButton = document.getElementById("startCamera");
const capturePhotoButton = document.getElementById("capturePhoto");
const webcamVideo = document.getElementById("webcam");
const captureCanvas = document.getElementById("captureCanvas");
const cameraPlaceholder = document.getElementById("cameraPlaceholder");
const cameraGuide = document.getElementById("cameraGuide");
const cameraFrame = document.getElementById("cameraFrame");
const viewfinderBox = document.getElementById("viewfinderBox");
const classifyButton = document.getElementById("classifyButton");
const modelStatus = document.getElementById("modelStatus");
const scoresList = document.getElementById("scoresList");

function setModelStatus(message, ready = false) {
  modelStatus.textContent = message;
  modelStatus.classList.toggle("ready", ready);
}

function setSelectedImage(source, label) {
  selectedImage = source;
  imagePreview.src = source;
  imagePreview.hidden = false;
  if (emptyPreview) emptyPreview.hidden = true;
  if (previewWrap) {
    previewWrap.classList.add("has-image");
    previewWrap.classList.remove("zoomed");
  }
  if (previewViewfinder) previewViewfinder.hidden = false;
  if (previewBadge) previewBadge.hidden = false;
  if (previewZoomBtn) {
    previewZoomBtn.hidden = false;
    if (zoomIcon) zoomIcon.textContent = "🔍 Zoom in";
  }
  imageStatus.textContent = label || "Image ready";
  classifyButton.disabled = false;
}

// Toggle zoom on preview image for inspecting close-up details
if (previewZoomBtn) {
  previewZoomBtn.addEventListener("click", (e) => {
    e.stopPropagation();
    if (!previewWrap) return;
    const isZoomed = previewWrap.classList.toggle("zoomed");
    if (zoomIcon) {
      zoomIcon.textContent = isZoomed ? "✕ Reset zoom" : "🔍 Zoom in";
    }
  });
}

if (imagePreview) {
  imagePreview.addEventListener("click", () => {
    if (!previewWrap || !selectedImage) return;
    const isZoomed = previewWrap.classList.toggle("zoomed");
    if (zoomIcon) {
      zoomIcon.textContent = isZoomed ? "✕ Reset zoom" : "🔍 Zoom in";
    }
  });
}

imageInput.addEventListener("change", (event) => {
  const file = event.target.files && event.target.files[0];
  if (!file) return;
  if (!file.type.startsWith("image/")) {
    imageStatus.textContent = "Please choose an image file.";
    return;
  }
  const reader = new FileReader();
  reader.onload = () => setSelectedImage(reader.result, file.name);
  reader.onerror = () => {
    imageStatus.textContent = "Could not read that image. Try another file.";
  };
  reader.readAsDataURL(file);
});

async function loadModel() {
  if (model) return model;
  if (modelLoading) return modelLoading;

  if (!window.tmImage) {
    throw new Error("The Teachable Machine library did not load. Check your internet connection and refresh the page.");
  }
  modelLoading = (async () => {
    setModelStatus("Loading AI model…");
    const base = MODEL_URL.endsWith("/") ? MODEL_URL : MODEL_URL + "/";
    const loadedModel = await tmImage.load(base + "model.json", base + "metadata.json");
    model = loadedModel;
    setModelStatus("AI model connected. Ready to classify.", true);
    return model;
  })();

  try {
    return await modelLoading;
  } catch (error) {
    modelLoading = null;
    setModelStatus("Could not load the AI model. Check the model URL and try again.");
    throw error;
  }
}

// Start camera with high-resolution constraints
startCameraButton.addEventListener("click", async () => {
  startCameraButton.disabled = true;
  imageStatus.textContent = "Starting high-resolution camera…";
  try {
    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
      throw new Error("Camera access is unavailable. Open this site using HTTPS or localhost in a supported browser.");
    }
    if (cameraStream) {
      cameraStream.getTracks().forEach((track) => track.stop());
      cameraStream = null;
    }

    cameraStream = await navigator.mediaDevices.getUserMedia({
      video: {
        facingMode: { ideal: "environment" },
        width: { ideal: 1280, min: 640 },
        height: { ideal: 720, min: 480 }
      },
      audio: false
    });

    webcamVideo.srcObject = cameraStream;
    webcamVideo.hidden = false;
    cameraPlaceholder.hidden = true;
    if (cameraGuide) cameraGuide.hidden = false;

    await webcamVideo.play();
    capturePhotoButton.disabled = false;
    imageStatus.textContent = "Camera active. Align leaf/fruit inside the target frame.";
    startCameraButton.textContent = "Restart camera";
  } catch (error) {
    console.error("EggplantGuard camera error:", error);
    let message = error.message || "Camera could not be started.";
    if (error.name === "NotAllowedError" || error.name === "PermissionDeniedError") {
      message = "Camera permission was blocked. Allow camera access in your browser's site settings, then try again.";
    } else if (error.name === "NotFoundError" || error.name === "DevicesNotFoundError") {
      message = "No camera was found. Connect a camera or use Upload an image instead.";
    } else if (error.name === "NotReadableError" || error.name === "TrackStartError") {
      message = "The camera may already be in use by another app. Close other apps using it and try again.";
    }
    imageStatus.textContent = message;
    alert(message);
  } finally {
    startCameraButton.disabled = false;
  }
});

// Accurate capture: What is framed in the viewfinder is 100% what gets captured
capturePhotoButton.addEventListener("click", () => {
  if (!cameraStream || !webcamVideo.videoWidth) {
    alert("Start the camera and wait for the video preview before capturing.");
    return;
  }

  const videoWidth = webcamVideo.videoWidth;
  const videoHeight = webcamVideo.videoHeight;
  const frameRect = cameraFrame.getBoundingClientRect();

  // Compute exact scale and offsets applied by object-fit: cover
  const scale = Math.max(frameRect.width / videoWidth, frameRect.height / videoHeight);
  const renderedWidth = videoWidth * scale;
  const renderedHeight = videoHeight * scale;

  const offsetX = (renderedWidth - frameRect.width) / 2 / scale;
  const offsetY = (renderedHeight - frameRect.height) / 2 / scale;

  let sx, sy, sWidth, sHeight;

  if (viewfinderBox && cameraGuide && !cameraGuide.hidden) {
    const vfRect = viewfinderBox.getBoundingClientRect();
    sx = Math.max(0, offsetX + (vfRect.left - frameRect.left) / scale);
    sy = Math.max(0, offsetY + (vfRect.top - frameRect.top) / scale);
    sWidth = Math.min(videoWidth - sx, vfRect.width / scale);
    sHeight = Math.min(videoHeight - sy, vfRect.height / scale);
  } else {
    sx = Math.max(0, offsetX);
    sy = Math.max(0, offsetY);
    sWidth = Math.min(videoWidth - sx, frameRect.width / scale);
    sHeight = Math.min(videoHeight - sy, frameRect.height / scale);
  }

  // Preserve 1:1 square aspect ratio without stretching
  const squareDim = Math.min(sWidth, sHeight);
  const cropX = Math.max(0, sx + (sWidth - squareDim) / 2);
  const cropY = Math.max(0, sy + (sHeight - squareDim) / 2);

  // Use crisp 448x448 canvas (2x of MobileNet 224x224)
  const targetDim = 448;
  captureCanvas.width = targetDim;
  captureCanvas.height = targetDim;
  const context = captureCanvas.getContext("2d");

  context.drawImage(webcamVideo, cropX, cropY, squareDim, squareDim, 0, 0, targetDim, targetDim);
  setSelectedImage(captureCanvas.toDataURL("image/png"), "Camera snapshot (viewfinder aligned)");
});

// Check if predicted class corresponds to an eggplant category
function isRecognizedEggplantClass(className) {
  const name = (className || "").toLowerCase();
  if (
    name.includes("not eggplant") ||
    name.includes("non-eggplant") ||
    name.includes("not_eggplant") ||
    name.includes("invalid") ||
    name.includes("other") ||
    name.includes("unknown") ||
    name.includes("background")
  ) {
    return false;
  }
  const isLeaf = name.includes("leaf");
  const isFruit = name.includes("fruit") || name.includes("eggplant") || name.includes("borer");
  return isLeaf || isFruit;
}

// Sample image pixels to check for eggplant/plant visual characteristics
function checkEggplantVisualFeatures(imgElement) {
  try {
    const canvas = document.createElement("canvas");
    canvas.width = 64;
    canvas.height = 64;
    const ctx = canvas.getContext("2d");
    ctx.drawImage(imgElement, 0, 0, 64, 64);
    const imgData = ctx.getImageData(0, 0, 64, 64).data;
    let matchedPixels = 0;
    const totalPixels = 64 * 64;

    for (let i = 0; i < imgData.length; i += 4) {
      const r = imgData[i];
      const g = imgData[i + 1];
      const b = imgData[i + 2];

      const max = Math.max(r, g, b);
      const min = Math.min(r, g, b);
      const delta = max - min;
      let h = 0;
      if (delta !== 0) {
        if (max === r) h = ((g - b) / delta) % 6;
        else if (max === g) h = (b - r) / delta + 2;
        else h = (r - g) / delta + 4;
        h = Math.round(h * 60);
        if (h < 0) h += 360;
      }
      const s = max === 0 ? 0 : delta / max;
      const v = max / 255;

      // 1. Green leaf foliage: hue 50° - 175°
      const isGreenLeaf = (h >= 50 && h <= 175 && s >= 0.12 && v >= 0.12);
      // 2. Leaf miner / damaged dry areas: yellowish-brown
      const isLeafDamage = (h >= 22 && h < 50 && s >= 0.16 && v >= 0.16);
      // 3. Purple / violet eggplant fruit: hue 245° - 340°
      const isPurpleFruit = (h >= 245 && h <= 340 && s >= 0.10 && v >= 0.08);
      // 4. Dark ripe eggplant tones (low brightness with red/blue presence)
      const isDarkFruit = (v < 0.24 && max > 8 && (b >= g || r >= g));

      if (isGreenLeaf || isLeafDamage || isPurpleFruit || isDarkFruit) {
        matchedPixels++;
      }
    }

    const ratio = matchedPixels / totalPixels;
    return ratio >= 0.05;
  } catch (err) {
    return true;
  }
}

// Pre-crop image element to square canvas before classifying to eliminate distortion
function prepareSquareInput(imgElement) {
  const canvas = document.createElement("canvas");
  const size = 224;
  canvas.width = size;
  canvas.height = size;
  const ctx = canvas.getContext("2d");

  const naturalWidth = imgElement.naturalWidth || imgElement.width || size;
  const naturalHeight = imgElement.naturalHeight || imgElement.height || size;
  const cropDim = Math.min(naturalWidth, naturalHeight);
  const sx = (naturalWidth - cropDim) / 2;
  const sy = (naturalHeight - cropDim) / 2;

  ctx.drawImage(imgElement, sx, sy, cropDim, cropDim, 0, 0, size, size);
  return canvas;
}

function getAdvice(className) {
  const name = className.toLowerCase();
  if (name.includes("healthy") && name.includes("leaf")) {
    return { icon: "🌿", description: "The image most closely matches healthy leaf examples.", advice: "Continue regular plant monitoring and maintain proper watering and field sanitation." };
  }
  if (name.includes("leaf miner") || name.includes("leaf-miner")) {
    return { icon: "🍃", description: "The image most closely matches leaf-miner damage examples.", advice: "Inspect nearby leaves for winding trails or larvae, remove heavily affected leaves when appropriate, and consult local agricultural guidance." };
  }
  if (name.includes("fresh") || name.includes("market-ready") || name.includes("market ready")) {
    return { icon: "🍆", description: "The image most closely matches fresh, market-ready fruit examples.", advice: "Check firmness and surface condition, then handle and store the eggplant carefully to prevent bruising." };
  }
  if (name.includes("damaged") || name.includes("borer")) {
    return { icon: "⚠️", description: "The image most closely matches damaged or borer-infested fruit examples.", advice: "Inspect for holes, frass, and internal damage. Separate affected fruit and seek local agricultural advice for pest management." };
  }
  return { icon: "🔎", description: "The model selected the closest class in its training data.", advice: "Review the image and compare it with the training examples. This AI result is an educational estimate, not a confirmed diagnosis." };
}

classifyButton.addEventListener("click", async () => {
  if (!selectedImage || !imagePreview.src) {
    alert("Choose an image or capture a photo first.");
    return;
  }
  classifyButton.disabled = true;
  classifyButton.textContent = "Classifying…";
  setModelStatus("Analyzing image with AI model…");

  try {
    const loadedModel = await loadModel();

    // Prepare square input so MobileNet features are undistorted
    const squaredCanvas = prepareSquareInput(imagePreview);
    const predictions = await loadedModel.predict(squaredCanvas);

    if (!predictions || predictions.length === 0) {
      throw new Error("The model returned no predictions. Check that the trained model has classes.");
    }

    predictions.sort((a, b) => b.probability - a.probability);
    const best = predictions[0];

    // Check validity
    const isEggplantClass = isRecognizedEggplantClass(best.className);
    const hasSufficientConfidence = best.probability >= CONFIDENCE_THRESHOLD;
    const hasVisualFeatures = checkEggplantVisualFeatures(imagePreview);

    const isValidEggplant = isEggplantClass && hasSufficientConfidence && hasVisualFeatures;

    const resultSection = document.getElementById("resultSection");
    const resultCaption = document.getElementById("resultCaption");
    const resultIcon = document.getElementById("resultIcon");
    const resultLabel = document.getElementById("resultLabel");
    const resultDescription = document.getElementById("resultDescription");
    const confidenceValue = document.getElementById("confidenceValue");
    const confidenceBar = document.getElementById("confidenceBar");
    const adviceTitle = document.getElementById("adviceTitle");
    const recommendation = document.getElementById("recommendation");

    // Populate all prediction probabilities
    if (scoresList) {
      scoresList.innerHTML = "";
      predictions.forEach((pred) => {
        const pct = Math.round(pred.probability * 100);
        const row = document.createElement("div");
        row.className = "score-row";
        row.innerHTML = `
          <div class="score-row-info">
            <span>${pred.className}</span>
            <span>${pct}%</span>
          </div>
          <div class="score-bar-bg">
            <div class="score-bar-fill" style="width: ${pct}%"></div>
          </div>
        `;
        scoresList.appendChild(row);
      });
    }

    if (!isValidEggplant) {
      let reasonText = "The uploaded sample was not recognized as an eggplant leaf or fruit.";
      if (!isEggplantClass) {
        reasonText = "The detected category is not an eggplant leaf or fruit.";
      } else if (!hasVisualFeatures) {
        reasonText = "The image lacks typical eggplant leaf or fruit visual features.";
      } else if (!hasSufficientConfidence) {
        reasonText = `Confidence is too low (${Math.round(best.probability * 100)}% < 65%) to confirm this is an eggplant.`;
      }

      resultSection.classList.add("result-invalid");
      if (resultCaption) resultCaption.textContent = "VERIFICATION FAILED";
      resultIcon.textContent = "🚫";
      resultLabel.textContent = "Invalid: Not an Eggplant";
      resultDescription.textContent = reasonText;
      confidenceValue.textContent = Math.round(best.probability * 100) + "%";
      confidenceBar.style.width = Math.round(best.probability * 100) + "%";
      if (adviceTitle) adviceTitle.textContent = "Why is this invalid?";
      recommendation.textContent = "EggplantGuard is designed specifically for screening eggplant leaves and fruits. Please frame an eggplant leaf or fruit clearly inside the target viewfinder without busy backgrounds.";
      resultSection.hidden = false;
      setModelStatus("Classification complete: Result is invalid (not an eggplant).", false);
    } else {
      resultSection.classList.remove("result-invalid");
      if (resultCaption) resultCaption.textContent = "TOP PREDICTION";
      const advice = getAdvice(best.className);
      resultIcon.textContent = advice.icon;
      resultLabel.textContent = best.className;
      resultDescription.textContent = advice.description;
      confidenceValue.textContent = Math.round(best.probability * 100) + "%";
      confidenceBar.style.width = Math.round(best.probability * 100) + "%";
      if (adviceTitle) adviceTitle.textContent = "Recommended next step";
      recommendation.textContent = advice.advice;
      resultSection.hidden = false;
      setModelStatus("Classification complete.", true);
    }
  } catch (error) {
    console.error("EggplantGuard classification error:", error);
    setModelStatus(error.message || "Classification failed. Open the browser console for details.");
    alert("Classification failed: " + (error.message || "Unknown error") + "\n\nCheck that the model URL is valid and that model.json and metadata.json can load.");
  } finally {
    classifyButton.disabled = !selectedImage;
    classifyButton.textContent = "✦ Classify image";
  }
});

window.addEventListener("beforeunload", () => {
  if (cameraStream) cameraStream.getTracks().forEach((track) => track.stop());
});

setModelStatus("Model URL added. The AI model will load when you classify an image.");
