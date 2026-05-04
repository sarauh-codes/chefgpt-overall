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
    const tbody = document.getElementById("meal-plan-body");
    tbody.innerHTML = "";
    DAYS.forEach((day) => {
      const tr = document.createElement("tr");
      tr.dataset.day = day;
      tr.innerHTML =
        '<th scope="row">' +
        day +
        '</th><td class="meal-plan-empty">—</td>';
      tbody.appendChild(tr);
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

  function renderPlan(plan) {
    const tbody = document.getElementById("meal-plan-body");
    tbody.innerHTML = "";
    plan.forEach((item) => {
      const tr = document.createElement("tr");
      tr.dataset.day = item.day;

      const th = document.createElement("th");
      th.scope = "row";
      th.textContent = item.day;

      const td = document.createElement("td");
      const inner = document.createElement("div");
      inner.className = "meal-plan-cell-inner";

      if (item.image_url) {
        const img = document.createElement("img");
        img.className = "meal-plan-thumb";
        img.alt = "";
        img.loading = "lazy";
        img.src = item.image_url;
        img.onerror = function () {
          img.style.display = "none";
        };
        inner.appendChild(img);
      }

      const textWrap = document.createElement("div");
      const nameEl = document.createElement("div");
      nameEl.className = "meal-plan-recipe-name";
      const a = document.createElement("a");
      a.href = "/recipe/" + encodeURIComponent(String(item.recipe_id));
      a.textContent = item.recipe_name;
      nameEl.appendChild(a);

      const meta = document.createElement("div");
      meta.className = "meal-plan-meta";
      ["🍽️ " + item.cuisine, "🔥 " + item.calories + " cal", "⭐ " + item.rating + "/5"].forEach(
        function (text) {
          const span = document.createElement("span");
          span.textContent = text;
          meta.appendChild(span);
        }
      );

      textWrap.appendChild(nameEl);
      textWrap.appendChild(meta);
      inner.appendChild(textWrap);
      td.appendChild(inner);
      tr.appendChild(th);
      tr.appendChild(td);
      tbody.appendChild(tr);
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
  });

  document.getElementById("btn-randomize-week").addEventListener("click", async function () {
    const btn = this;
    hideError();

    const cuisine = document.getElementById("filter-cuisine").value.trim();
    const maxCalRaw = document.getElementById("filter-max-cal").value.trim();
    const minRatingRaw = document.getElementById("filter-min-rating").value.trim();
    const difficulty = document.getElementById("filter-difficulty").value;

    const payload = {
      cuisine: cuisine || undefined,
      max_calories: maxCalRaw ? parseInt(maxCalRaw, 10) : undefined,
      min_rating: minRatingRaw ? parseFloat(minRatingRaw) : undefined,
      difficulty: difficulty,
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
