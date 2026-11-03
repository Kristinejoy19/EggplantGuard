# EggplantGuard

EggplantGuard is an educational prototype for classifying eggplant leaf conditions and fruit quality with a Google Teachable Machine image model. It includes a browser app and a Streamlit app; both currently use the same hosted model.

## Files
- `index.html` — page structure and library imports
- `style.css` — responsive visual design
- `script.js` — upload, webcam capture, model loading, prediction, and advice

## 1. Train and export your model
1. Open https://teachablemachine.withgoogle.com/
2. Create an **Image Project** with these four class labels:
   - `Healthy Leaf`
   - `Leaf Miner Damage`
   - `Fresh/Market-Ready Fruit`
   - `Damaged/Borer-Infested Fruit`
3. Add representative images to each class and click **Train Model**.
4. Test the model with images not used for training.
5. Select **Export Model** → **TensorFlow.js** → upload/host the model, if available.
6. Copy the URL provided by Teachable Machine.

## 2. Connect the model
Open `script.js` and replace:
```js
const MODEL_URL = "https://teachablemachine.withgoogle.com/models/jq8kSVI_-/";
```
with your model URL, preserving the trailing slash. To keep both app versions consistent, update `MODEL_URL` in `app.py` to the same URL.
```js
const MODEL_URL = "https://teachablemachine.withgoogle.com/models/YOUR_REAL_MODEL_ID/";
```

Make sure your model's class names match the four labels exactly. If they differ, update `getAdvice` in `script.js` and `GUIDANCE` in `app.py`.

## 3. Run locally
- Open the folder in Visual Studio Code.
- Install the **Live Server** extension, then right-click `index.html` and choose **Open with Live Server**.
- An internet connection is required for the hosted JavaScript libraries and a hosted Teachable Machine model.
- Camera access normally requires HTTPS or localhost. If camera permission fails, try image upload.

## 4. Publish on GitHub Pages
1. Create a GitHub repository named `EggplantGuard`.
2. Upload `index.html`, `style.css`, and `script.js` to the repository root.
3. Open **Settings → Pages**.
4. Under Build and deployment, choose **Deploy from a branch**, select `main` and `/ (root)`, then save.
5. Wait for the published Pages URL and open it.
6. Test both image upload and camera access. Use the HTTPS published URL for camera permission.

## 5. Run the Streamlit app
- Install dependencies with `pip install -r requirements.txt`.
- Run `streamlit run app.py` from the repository root.
- The Streamlit app loads the hosted model at startup; an internet connection is required.

## Important notes
- The browser app and Streamlit app are configured to use the same hosted model URL.
- `model.json`, `metadata.json`, and `weights.bin` are included in the repository; the apps currently load the hosted model rather than these local files.
- This prototype provides educational screening, not a certified plant diagnosis.
- Do not report accuracy figures such as 88.5% as measured results unless you have evaluated your model on a real held-out test set.
