# EggplantGuard — MySQL Database Documentation

This database schema is designed specifically for **EggplantGuard**, an AI-assisted eggplant crop screening and fruit quality assessment system.

## 📁 Schema File
- [`eggplantguard.sql`](./eggplantguard.sql) (also mirrored at the project root: [`../eggplantguard.sql`](../eggplantguard.sql))

---

## 🗄️ Database Architecture

The schema contains 8 core relational tables and 2 analytical views:

```text
                  ┌───────────────┐
                  │     users     │
                  └───────┬───────┘
                          │ 1:N
                          ▼
┌───────────────┐  ┌──────────────┐
│   ai_models   │  │    farms     │
└───────┬───────┘  └──────┬───────┘
        │ 1:N             │ 1:N
        └────────┐   ┌────┘
                 ▼   ▼
            ┌──────────────┐          ┌─────────────────────────┐
            │    scans     ├─────────►│  diagnostic_categories │
            └──────┬───────┘ 1:1      └─────────────────────────┘
                   │
         ┌─────────┴─────────┐
     1:N │                   │ 1:1
         ▼                   ▼
┌──────────────────┐  ┌──────────────────┐
│ scan_predictions │  │  expert_reviews  │
└──────────────────┘  └──────────────────┘
```

---

## 📋 Table Descriptions

| Table | Purpose |
|---|---|
| **`users`** | Stores system accounts for farmers, agricultural technicians, researchers, and administrators. |
| **`farms`** | Records eggplant farms, locations, crop plot sizes, and varieties (e.g. *Long Purple*, *Black Beauty*). |
| **`ai_models`** | Tracks deployed AI models (e.g. Teachable Machine URL, input size `224x224`, and threshold `0.70`). |
| **`diagnostic_categories`** | Official catalog of eggplant states (`Healthy Leaf`, `Leaf Miner Damage`, `Fresh Fruit`, `Damaged Fruit`, `Invalid`). |
| **`scans`** | Central log of every screening. Stores input method (`upload` or `camera`), confidence, validity status (`is_valid_eggplant`), and rejection reasons for non-eggplants. |
| **`scan_predictions`** | Full probability distribution across all classes for each scan. |
| **`expert_reviews`** | Ground truth feedback and validation from agricultural technicians to evaluate model accuracy. |
| **`system_settings`** | Key-value store for runtime thresholds (`CONFIDENCE_THRESHOLD = 0.70`) and configuration. |

---

## 🚀 How to Import into MySQL

### Method 1: Using XAMPP / phpMyAdmin (Recommended for GUI)
1. Open the **XAMPP Control Panel** and click **Start** next to **MySQL** and **Apache**.
2. Open your browser and go to: `http://localhost/phpmyadmin/`.
3. In phpMyAdmin, click the **Import** tab at the top.
4. Click **Choose File** and select [`eggplantguard.sql`](./eggplantguard.sql).
5. Click **Import** (or **Go**) at the bottom.
6. The `eggplantguard` database will be created with all tables, seed data, and views ready to use.

---

### Method 2: Using MySQL Command Line (Windows Terminal / PowerShell)
If MySQL is installed via XAMPP or standalone:

```powershell
# In PowerShell:
& "C:\xampp\mysql\bin\mysql.exe" -u root -p < database/eggplantguard.sql
```
*(Press Enter if you do not have a password set on root).*

---

## 🔍 Useful Example SQL Queries

### 1. View all recent scans with status and validation results
```sql
SELECT 
  scan_id,
  scanned_at,
  top_prediction_label,
  CONCAT(ROUND(confidence_score * 100, 1), '%') AS confidence,
  CASE WHEN is_valid_eggplant = 1 THEN '✅ Valid' ELSE '🚫 Invalid' END AS validation_status,
  invalidation_reason
FROM scans
ORDER BY scanned_at DESC;
```

### 2. View scans that were flagged as "Invalid (Not an Eggplant)"
```sql
SELECT 
  scan_id,
  scanned_at,
  input_method,
  confidence_score,
  invalidation_reason
FROM scans
WHERE is_valid_eggplant = 0;
```

### 3. Check AI vs Expert Agreement Accuracy
```sql
SELECT * FROM v_expert_agreement_stats;
```

