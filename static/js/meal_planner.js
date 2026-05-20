(function () {
  const DAYS = [
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
    "Sunday",
  ];

  function resetRows() {
    const container = document.getElementById("meal-plan-body");
    container.innerHTML = "";
    DAYS.forEach((day) => {
      const card = document.createElement("div");
      card.className = "day-card";
      card.innerHTML = `
        <div class="day-header">${day}</div>
        <div class="day-card-empty">
            <div style="font-size: 32px;">🍽️</div>
            <div>No meal planned</div>
        </div>
      `;
      container.appendChild(card);
    });
  }

  function getValidDays() {
    const el = document.getElementById("meal-plan-valid-days");
    const n = el ? parseInt(el.textContent, 10) : NaN;
    return Number.isFinite(n) && n > 0 ? n : 7;
  }

  function showExpiryBanner(expiresDisplay) {
    const wrap = document.getElementById("meal-plan-expiry-banner");
    const holder = document.getElementById("meal-plan-expiry-text");
    holder.textContent = "";
    holder.appendChild(
      document.createTextNode(
        "Saved plan — refreshes automatically after " +
          getValidDays() +
          " days. Clears on "
      )
    );
    const strong = document.createElement("strong");
    strong.textContent = expiresDisplay;
    holder.appendChild(strong);
    holder.appendChild(document.createTextNode("."));
    wrap.style.display = "block";
  }

  function hideExpiryBanner() {
    const wrap = document.getElementById("meal-plan-expiry-banner");
    wrap.style.display = "none";
    document.getElementById("meal-plan-expiry-text").textContent = "";
  }

  function showError(msg) {
    const el = document.getElementById("meal-plan-error");
    el.textContent = msg;
    el.classList.add("visible");
  }

  function hideError() {
    const el = document.getElementById("meal-plan-error");
    el.textContent = "";
    el.classList.remove("visible");
  }

  function showSuccessNotice(text) {
    const el = document.getElementById("meal-plan-success-notice");
    el.textContent = text;
    el.classList.add("visible");
    el.style.display = "block";
  }

  function hideSuccessNotice() {
    const el = document.getElementById("meal-plan-success-notice");
    el.textContent = "";
    el.classList.remove("visible");
    el.style.display = "none";
  }

  function showPopup(message) {
    if (!message) return;
    const modal = document.getElementById("meal-planner-modal");
    const text = document.getElementById("meal-planner-modal-text");
    if (!modal || !text) return;
    text.textContent = message;
    modal.style.display = "flex";
  }

  function hidePopup() {
    const modal = document.getElementById("meal-planner-modal");
    if (!modal) return;
    modal.style.display = "none";
  }

  function hasOtherFilterValues() {
    const cuisine = document.getElementById("filter-cuisine").value.trim();
    const maxCalRaw = document.getElementById("filter-max-cal").value.trim();
    const minRatingRaw = document.getElementById("filter-min-rating").value.trim();
    const difficulty = document.getElementById("filter-difficulty").value;
    return Boolean(cuisine || maxCalRaw || minRatingRaw || (difficulty && difficulty !== "any"));
  }

  function syncExclusiveFilterState() {
    const baseSel = document.getElementById("filter-base-ingredient");
    const usingBase = Boolean(baseSel.value.trim());
    const usingOther = hasOtherFilterValues();

    const otherIds = ["filter-cuisine", "filter-max-cal", "filter-min-rating", "filter-difficulty"];
    otherIds.forEach((id) => {
      const el = document.getElementById(id);
      el.disabled = usingBase;
    });
    baseSel.disabled = usingOther;
  }

  function renderPlan(plan) {
    const container = document.getElementById("meal-plan-body");
    container.innerHTML = "";
    plan.forEach((item) => {
      const card = document.createElement("div");
      card.className = "day-card";

      let imgHTML = '';
      if (item.image_url) {
        imgHTML = `<img src="${item.image_url}" class="meal-plan-thumb" onerror="this.style.display='none'">`;
      } else {
        imgHTML = `<div class="recipe-img-placeholder" style="height:140px; background:var(--panel-2); display:flex; align-items:center; justify-content:center; font-size:48px;">🍲</div>`;
      }

      card.innerHTML = `
        <div class="day-header">${item.day}</div>
        <div class="recipe-card-img" style="position:relative;">
            ${imgHTML}
        </div>
        <div class="recipe-card-body" style="padding: 20px; flex: 1; display: flex; flex-direction: column;">
            <div class="meal-plan-recipe-name" style="font-size: 18px; font-weight: 700; margin-bottom: 8px;">
                <a href="/recipe/${item.recipe_id}" style="color: var(--text); text-decoration: none; transition: color 0.2s;">${item.recipe_name}</a>
            </div>
            <div class="meal-plan-meta" style="color: var(--muted); font-size: 13px; font-weight:500; margin-bottom: 20px; display:flex; gap:12px; flex-wrap:wrap;">
                <span>🍽️ ${item.cuisine}</span>
                <span>⏱ ${item.cook_time || '45'} min</span>
                <span>🔥 ${item.calories} cal</span>
                <span>⭐ ${item.rating}/5</span>
            </div>
            <a href="/recipe/${item.recipe_id}" class="view-recipe-btn" style="margin-top:auto; background:var(--brand); color:white; padding:12px; border-radius:25px; text-align:center; text-decoration:none; font-weight:700; font-size: 14px; transition:all 0.3s; box-shadow: 0 4px 12px var(--brand-soft);">Cook This! 🍳</a>
        </div>
      `;
      container.appendChild(card);
    });
  }

  function applySavedPayload(payload) {
    if (payload && payload.plan && payload.plan.length === 7 && payload.expires_display) {
      renderPlan(payload.plan);
      showExpiryBanner(payload.expires_display);
    } else {
      resetRows();
      hideExpiryBanner();
    }
  }

  document.addEventListener("DOMContentLoaded", function () {
    const bootEl = document.getElementById("meal-plan-bootstrap");
    try {
      const raw = bootEl ? bootEl.textContent.trim() : "";
      const boot = raw ? JSON.parse(raw) : null;
      applySavedPayload(boot);
    } catch (e) {
      resetRows();
      hideExpiryBanner();
    }

    ["filter-cuisine", "filter-max-cal", "filter-min-rating", "filter-difficulty", "filter-base-ingredient"]
      .forEach((id) => {
        document.getElementById(id).addEventListener("change", syncExclusiveFilterState);
        document.getElementById(id).addEventListener("input", syncExclusiveFilterState);
      });
    syncExclusiveFilterState();

    const closeBtn = document.getElementById("meal-planner-modal-close");
    const modal = document.getElementById("meal-planner-modal");
    if (closeBtn) closeBtn.addEventListener("click", hidePopup);
    if (modal) {
      modal.addEventListener("click", (evt) => {
        if (evt.target === modal) hidePopup();
      });
    }
  });

  document.getElementById("btn-randomize-week").addEventListener("click", async function () {
    const btn = this;
    hideError();

    const cuisine = document.getElementById("filter-cuisine").value.trim();
    const maxCalRaw = document.getElementById("filter-max-cal").value.trim();
    const minRatingRaw = document.getElementById("filter-min-rating").value.trim();
    const difficulty = document.getElementById("filter-difficulty").value;
    const baseIngredient = document.getElementById("filter-base-ingredient").value.trim();
    const usingBase = Boolean(baseIngredient);

    const payload = {
      cuisine: usingBase ? undefined : (cuisine || undefined),
      max_calories: usingBase ? undefined : (maxCalRaw ? parseInt(maxCalRaw, 10) : undefined),
      min_rating: usingBase ? undefined : (minRatingRaw ? parseFloat(minRatingRaw) : undefined),
      difficulty: usingBase ? "any" : difficulty,
      base_ingredient: usingBase ? baseIngredient : undefined,
    };

    btn.disabled = true;
    try {
      const res = await fetch("/api/meal-plan-week", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) {
        const extra =
          typeof data.available === "number"
            ? " (" + data.available + " recipe(s) match.)"
            : "";
        showError((data.error || "Could not build a meal plan.") + extra);
        if (data.popup_message) {
          showPopup(data.popup_message);
        }
        return;
      }
      if (data.plan && data.plan.length) {
        renderPlan(data.plan);
        if (data.expires_display) {
          showExpiryBanner(data.expires_display);
        }
        if (data.notice) {
          showSuccessNotice(data.notice);
        }
        if (data.popup_message) {
          showPopup(data.popup_message);
        }
      }
    } catch (e) {
      showError("Network error. Please try again.");
    } finally {
      btn.disabled = false;
    }
  });

  document.getElementById("btn-reset-plan").addEventListener("click", async function () {
    const btn = this;
    hideError();
    hideSuccessNotice();
    btn.disabled = true;
    try {
      const res = await fetch("/api/meal-plan-week", { method: "DELETE" });
      if (!res.ok) {
        showError("Could not clear your plan. Try again.");
        return;
      }
      resetRows();
      hideExpiryBanner();
    } catch (e) {
      showError("Network error. Please try again.");
    } finally {
      btn.disabled = false;
    }
  });
})();
