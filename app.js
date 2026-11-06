function cratePhoto() {
  const canvas = document.createElement("canvas");
  canvas.width = 800;
  canvas.height = 520;
  const g = canvas.getContext("2d");
  const sky = g.createLinearGradient(0, 0, 800, 520);
  sky.addColorStop(0, "#f6d7ae");
  sky.addColorStop(1, "#e7a56a");
  g.fillStyle = sky;
  g.fillRect(0, 0, 800, 520);
  g.fillStyle = "#8d4b2a";
  g.fillRect(70, 280, 660, 180);
  g.fillStyle = "#6d351c";
  g.fillRect(70, 280, 660, 16);
  [[210, 250], [330, 230], [450, 255], [570, 228], [280, 330], [410, 345], [540, 325]].forEach(([x, y], index) => {
    g.beginPath();
    g.fillStyle = index % 2 ? "#e15d24" : "#f08a3a";
    g.arc(x, y, 52, 0, Math.PI * 2);
    g.fill();
    g.beginPath();
    g.strokeStyle = "#2f6b3a";
    g.lineWidth = 3;
    g.moveTo(x, y - 48);
    g.lineTo(x + 8, y - 64);
    g.stroke();
  });
  return canvas.toDataURL("image/jpeg", 0.86);
}

const boards = [
  {
    id: "square",
    name: "休息处",
    hint: "坐下来歇一会",
    blurb: "不想赶路的时候就来这里。喝茶、发呆、说一句今天还好，都可以。",
    people: ["茶水", "窗边", "信号"],
    posts: [
      {
        id: "p1",
        name: "茶水",
        text: "休息室新到了一箱橘子。想拿的人直接来，不用打招呼。",
        time: "今天 09:20",
        likes: 6,
        liked: false,
        replies: [{ name: "窗边", text: "我下午过去，帮你留两个。" }]
      },
      {
        id: "p2",
        name: "信号",
        text: "靠窗的位子空着。谁要是走累了，过来坐一会儿。",
        time: "今天 11:05",
        likes: 2,
        liked: false,
        replies: []
      }
    ]
  },
  {
    id: "night",
    name: "文图部",
    hint: "文字和图片",
    blurb: "写一段，或者配一张图。看到喜欢的，就留下一句回应。",
    people: ["值夜", "灯"],
    posts: [
      {
        id: "p3",
        name: "值夜",
        text: "今天的云很好看，拍了一张放在这里。",
        time: "昨天 23:40",
        images: [cratePhoto()],
        likes: 4,
        liked: false,
        replies: [{ name: "灯", text: "颜色很暖，我存下来了。" }]
      }
    ]
  },
  {
    id: "work",
    name: "游戏吧",
    hint: "开一局",
    blurb: "找人一起玩、约时间、分享刚打完的一局，都丢在这里。",
    people: ["扳手", "仓库"],
    posts: [
      {
        id: "p4",
        name: "仓库",
        text: "晚上八点缺一个人。想玩的直接回我，来得及。",
        time: "今天 08:10",
        likes: 1,
        liked: false,
        replies: []
      }
    ]
  }
];

const NUMBER_SUFFIX = /[①-⑳㉑-㉟㊱-㊿]$/u;

function baseName(value) {
  return value.trim().replace(NUMBER_SUFFIX, "");
}

function takenNames() {
  const taken = new Set();
  boards.forEach((board) => {
    board.people.forEach((name) => taken.add(name));
    board.posts.forEach((post) => {
      if (!post.mine && post.name) taken.add(post.name);
      post.replies.forEach((reply) => {
        if (!reply.mine && reply.name) taken.add(reply.name);
      });
    });
  });
  state.aliases.forEach((alias) => {
    if (alias.name) taken.delete(alias.name);
  });
  return taken;
}

function loadProfile() {
  const saved = sessionStorage.getItem("rhodes-profile");
  if (saved) {
    try {
      const parsed = JSON.parse(saved);
      if (Array.isArray(parsed.aliases) && parsed.aliases.length === 2) return parsed;
    } catch (error) {
      console.warn(error);
    }
  }
  let names = ["", ""];
  let active = 0;
  const legacy = sessionStorage.getItem("rhodes-names");
  if (legacy) {
    try {
      const parsed = JSON.parse(legacy);
      if (Array.isArray(parsed.names)) names = [parsed.names[0] || "", parsed.names[1] || ""];
      active = parsed.active || 0;
    } catch (error) {
      console.warn(error);
    }
  } else {
    names[0] = sessionStorage.getItem("rhodes-name") || "";
  }
  const avatar = sessionStorage.getItem("rhodes-avatar") || "";
  return {
    active,
    aliases: [
      { name: names[0], avatar },
      { name: names[1], avatar: "" }
    ]
  };
}

const loadedProfile = loadProfile();
const state = {
  aliases: loadedProfile.aliases,
  active: loadedProfile.aliases[loadedProfile.active]?.name ? loadedProfile.active : 0,
  boardId: "square"
};
let pendingAvatars = state.aliases.map((alias) => alias.avatar);

function speaking() {
  return state.aliases[state.active] || state.aliases[0];
}

function saveProfile() {
  sessionStorage.setItem("rhodes-profile", JSON.stringify({
    active: state.active,
    aliases: state.aliases
  }));
  sessionStorage.setItem("rhodes-name", speaking().name || "");
}

const gate = document.querySelector("#gate");
const home = document.querySelector("#home");
const gateForm = document.querySelector("#gate-form");
const gateName = document.querySelector("#gate-name");
const gateNameB = document.querySelector("#gate-name-b");
const gateError = document.querySelector("#gate-error");
const suffixes = document.querySelector("#suffixes");
const gateSubmit = document.querySelector("#gate-submit");
let nameTarget = null;
const meAvatar = document.querySelector("#me-avatar");
const composerAvatar = document.querySelector("#composer-avatar");
const boardNav = document.querySelector("#boards");
const boardHint = document.querySelector("#board-hint");
const boardBlurb = document.querySelector("#board-blurb");
const feed = document.querySelector("#feed");
const people = document.querySelector("#people");
const composer = document.querySelector("#composer");
const postText = document.querySelector("#post-text");
const postImages = document.querySelector("#post-images");
const previews = document.querySelector("#previews");
const composeError = document.querySelector("#compose-error");
const count = document.querySelector("#count");
const viewer = document.querySelector("#viewer");
const viewerImg = document.querySelector("#viewer-img");
const draftImages = [];

function currentBoard() {
  return boards.find((board) => board.id === state.boardId);
}

function escapeHtml(value) {
  return value.replace(/[&<>"']/g, (char) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;"
  }[char]));
}

function avatarMarkup(name, avatar) {
  if (avatar) return `<span class="avatar has-photo"><img src="${avatar}" alt="" /></span>`;
  return `<span class="avatar">${escapeHtml((name || "岛").slice(0, 1))}</span>`;
}

function paintAvatar(element, name, avatar) {
  if (avatar) {
    element.classList.add("has-photo");
    element.innerHTML = `<img src="${avatar}" alt="" />`;
    return;
  }
  element.classList.remove("has-photo");
  element.textContent = (name || "+").slice(0, 1);
}

function nameFields() {
  return [gateName, gateNameB];
}

function blockedName(candidate, field) {
  if (!candidate) return false;
  const other = nameFields().find((input) => input !== field);
  if (other && other.value.trim() === candidate) return true;
  return takenNames().has(candidate);
}

function paintGate() {
  const typed = [gateName.value, gateNameB.value];
  document.querySelectorAll(".gate-avatar").forEach((element, index) => {
    paintAvatar(element, typed[index].trim() || "+", pendingAvatars[index]);
  });
  document.querySelectorAll(".clear-avatar").forEach((button, index) => {
    button.hidden = !pendingAvatars[index];
  });
  const field = nameTarget || gateName;
  const current = field.value.trim();
  suffixes.querySelectorAll("[data-mark]").forEach((button) => {
    const candidate = `${baseName(field.value)}${button.dataset.mark}`;
    button.classList.toggle("on", current.endsWith(button.dataset.mark));
    button.disabled = !baseName(field.value) || blockedName(candidate, field);
  });
}

function renderSwitch() {
  const markup = [0, 1].map((index) => {
    const name = state.aliases[index].name;
    const on = Boolean(name) && index === state.active;
    return `<button type="button" class="${on ? "on" : ""}" data-alias="${index}">${escapeHtml(name || "添加名字")}</button>`;
  }).join("");
  document.querySelectorAll("[data-switch]").forEach((group) => {
    group.innerHTML = markup;
  });
}

function showHome() {
  gate.hidden = true;
  home.hidden = false;
  const current = speaking();
  paintAvatar(meAvatar, current.name, current.avatar);
  paintAvatar(composerAvatar, current.name, current.avatar);
  renderSwitch();
  render();
}

function openGate(editing, focusSecond) {
  home.hidden = true;
  gate.hidden = false;
  gateName.value = state.aliases[0].name;
  gateNameB.value = state.aliases[1].name;
  nameTarget = focusSecond ? gateNameB : gateName;
  pendingAvatars = state.aliases.map((alias) => alias.avatar);
  gateSubmit.textContent = editing ? "保存" : "进入";
  gateError.hidden = true;
  paintGate();
  (focusSecond ? gateNameB : gateName).focus();
}

function render() {
  const board = currentBoard();
  boardHint.textContent = `发到${board.name}，${board.hint}`;
  boardBlurb.textContent = board.blurb;
  boardNav.innerHTML = boards.map((item) => `
    <button class="board${item.id === board.id ? " active" : ""}" type="button" data-id="${item.id}">
      ${item.name}<small>${item.posts.length} 条</small>
    </button>
  `).join("");

  const listed = state.aliases.filter((alias) => alias.name).map((alias, index) => ({
    name: alias.name,
    avatar: alias.avatar,
    tag: state.aliases.indexOf(alias) === state.active ? " · 正在发言" : " · 你"
  }));
  board.people.forEach((name) => {
    if (!state.aliases.some((alias) => alias.name === name)) listed.push({ name, avatar: "", tag: "" });
  });
  people.innerHTML = listed.map((person) => `
    <li>${avatarMarkup(person.name, person.avatar)}<span>${escapeHtml(person.name)}${person.tag}</span></li>
  `).join("");

  feed.innerHTML = board.posts.map((post) => `
    <article class="post" data-id="${post.id}">
      <header class="post-head">
        <div>
          ${avatarMarkup(post.name, post.avatar)}
          <div>
            <h3>${escapeHtml(post.name)}</h3>
            <time>${escapeHtml(post.time)}</time>
          </div>
        </div>
      </header>
      ${post.text ? `<p class="body">${escapeHtml(post.text)}</p>` : ""}
      ${post.images?.length ? `<div class="photos ${post.images.length > 1 ? "many" : "one"}">${post.images.map((src, index) => `
        <button type="button" data-photo="${post.id}:${index}"><img src="${src}" alt="配图 ${index + 1}" /></button>
      `).join("")}</div>` : ""}
      <div class="actions">
        <button class="ghost like${post.liked ? " on" : ""}" type="button" data-like="${post.id}">喜欢 ${post.likes}</button>
        <button class="ghost reply-toggle" type="button" data-reply="${post.id}">回应 ${post.replies.length}</button>
      </div>
      ${post.replies.length ? `<div class="replies">${post.replies.map((reply) => `
        <div class="reply">
          ${avatarMarkup(reply.name, reply.avatar)}
          <div><strong>${escapeHtml(reply.name)}</strong><p>${escapeHtml(reply.text)}</p></div>
        </div>
      `).join("")}</div>` : ""}
      <form class="reply-box" data-for="${post.id}" hidden>
        <input maxlength="80" placeholder="回应 ${escapeHtml(post.name)}…" required />
        <button class="send-reply" type="submit">发送</button>
      </form>
    </article>
  `).join("") || `<article class="post"><p class="body">这个版块还没有人说话。你来写第一条。</p></article>`;
}

function fileToAvatar(file) {
  return readFile(file).then((url) => new Promise((resolve, reject) => {
    const image = new Image();
    image.onload = () => {
      const size = 256;
      const canvas = document.createElement("canvas");
      canvas.width = size;
      canvas.height = size;
      const scale = Math.max(size / image.width, size / image.height);
      const width = image.width * scale;
      const height = image.height * scale;
      const context = canvas.getContext("2d");
      context.drawImage(image, (size - width) / 2, (size - height) / 2, width, height);
      resolve(canvas.toDataURL("image/jpeg", 0.85));
    };
    image.onerror = () => reject(new Error("bad-image"));
    image.src = url;
  }));
}

function stampIdentity(entry, aliases) {
  if (!entry.mine) return;
  const slot = entry.alias === undefined ? 0 : entry.alias;
  const alias = aliases[slot] && aliases[slot].name ? aliases[slot] : aliases[0];
  entry.alias = aliases[slot] && aliases[slot].name ? slot : 0;
  entry.name = alias.name;
  entry.avatar = alias.avatar;
}

function applyProfile(aliases) {
  boards.forEach((board) => {
    board.posts.forEach((post) => {
      stampIdentity(post, aliases);
      post.replies.forEach((reply) => stampIdentity(reply, aliases));
    });
  });
  state.aliases = aliases;
  if (!state.aliases[state.active].name) state.active = 0;
  saveProfile();
}

gateForm.addEventListener("change", async (event) => {
  const input = event.target.closest(".avatar-file");
  if (!input) return;
  const file = input.files[0];
  input.value = "";
  const slot = Number(input.dataset.slot);
  if (!file) return;
  if (!file.type.startsWith("image/") || file.size > 8 * 1024 * 1024) {
    gateError.textContent = "请从相册选一张小于 8MB 的图片。";
    gateError.hidden = false;
    return;
  }
  pendingAvatars[slot] = await fileToAvatar(file);
  gateError.hidden = true;
  paintGate();
});

gateForm.addEventListener("click", (event) => {
  const button = event.target.closest(".clear-avatar");
  if (!button) return;
  pendingAvatars[Number(button.dataset.slot)] = "";
  paintGate();
});

nameFields().forEach((input) => {
  input.addEventListener("focus", () => {
    nameTarget = input;
    paintGate();
  });
  input.addEventListener("input", paintGate);
});

suffixes.addEventListener("mousedown", (event) => {
  if (event.target.closest("[data-mark]")) event.preventDefault();
});

suffixes.addEventListener("click", (event) => {
  const button = event.target.closest("[data-mark]");
  if (!button || button.disabled) return;
  const field = nameTarget || gateName;
  const base = baseName(field.value);
  if (!base) {
    gateError.textContent = "先写名字，再选编号。";
    gateError.hidden = false;
    field.focus();
    return;
  }
  field.value = `${base}${button.dataset.mark}`;
  gateError.hidden = true;
  paintGate();
});

gateForm.addEventListener("submit", (event) => {
  event.preventDefault();
  const first = gateName.value.trim();
  const second = gateNameB.value.trim();
  if (!baseName(first)) {
    gateError.textContent = "先写一个名字，再进来。";
    gateError.hidden = false;
    gateName.focus();
    return;
  }
  if (second && first === second) {
    gateError.textContent = "两个名字不能完全一样，换一个编号。";
    gateError.hidden = false;
    gateNameB.focus();
    return;
  }
  const taken = takenNames();
  const conflict = [first, second].find((name) => name && taken.has(name));
  if (conflict) {
    gateError.textContent = `「${conflict}」已经有人用了，换一个编号。`;
    gateError.hidden = false;
    return;
  }
  applyProfile([
    { name: first, avatar: pendingAvatars[0] },
    { name: second, avatar: second ? pendingAvatars[1] : "" }
  ]);
  gateError.hidden = true;
  showHome();
});

document.querySelector("#leave").addEventListener("click", () => openGate(true));

document.addEventListener("click", (event) => {
  const button = event.target.closest("[data-alias]");
  if (!button || gate.hidden === false) return;
  const index = Number(button.dataset.alias);
  if (!state.aliases[index].name) {
    openGate(true, true);
    return;
  }
  state.active = index;
  saveProfile();
  showHome();
});

boardNav.addEventListener("click", (event) => {
  const button = event.target.closest(".board");
  if (!button) return;
  state.boardId = button.dataset.id;
  render();
});

postText.addEventListener("input", () => {
  count.textContent = `${postText.value.length} / 200`;
});

function renderPreviews() {
  previews.innerHTML = draftImages.map((src, index) => `
    <div class="thumb">
      <img src="${src}" alt="" />
      <button type="button" data-remove="${index}" aria-label="移除这张图">×</button>
    </div>
  `).join("");
}

function readFile(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result);
    reader.onerror = () => reject(reader.error);
    reader.readAsDataURL(file);
  });
}

postImages.addEventListener("change", async () => {
  const files = [...postImages.files];
  postImages.value = "";
  composeError.hidden = true;
  const room = 4 - draftImages.length;
  if (!room) {
    composeError.textContent = "一次最多四张图。";
    composeError.hidden = false;
    return;
  }
  const accepted = files.filter((file) => file.type.startsWith("image/")).slice(0, room);
  if (accepted.some((file) => file.size > 4 * 1024 * 1024)) {
    composeError.textContent = "单张图片请小于 4MB。";
    composeError.hidden = false;
    return;
  }
  const urls = await Promise.all(accepted.map(readFile));
  draftImages.push(...urls);
  renderPreviews();
});

previews.addEventListener("click", (event) => {
  const button = event.target.closest("[data-remove]");
  if (!button) return;
  draftImages.splice(Number(button.dataset.remove), 1);
  renderPreviews();
});

composer.addEventListener("submit", (event) => {
  event.preventDefault();
  const text = postText.value.trim();
  if (!text && !draftImages.length) {
    composeError.textContent = "写一点字，或配上一张图。";
    composeError.hidden = false;
    postText.focus();
    return;
  }
  const now = new Intl.DateTimeFormat("zh-CN", {
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23"
  }).format(new Date());
  currentBoard().posts.unshift({
    id: `me-${Date.now()}`,
    name: speaking().name,
    avatar: speaking().avatar,
    alias: state.active,
    mine: true,
    text,
    images: [...draftImages],
    time: `今天 ${now}`,
    likes: 0,
    liked: false,
    replies: []
  });
  postText.value = "";
  draftImages.length = 0;
  renderPreviews();
  count.textContent = "0 / 200";
  composeError.hidden = true;
  render();
});

feed.addEventListener("click", (event) => {
  const like = event.target.closest("[data-like]");
  const reply = event.target.closest("[data-reply]");
  const photo = event.target.closest("[data-photo]");
  const board = currentBoard();
  if (photo) {
    const [id, index] = photo.dataset.photo.split(":");
    const post = board.posts.find((item) => item.id === id);
    viewerImg.src = post.images[Number(index)];
    viewerImg.alt = `${post.name}的配图`;
    viewer.showModal();
    return;
  }
  if (like) {
    const post = board.posts.find((item) => item.id === like.dataset.like);
    post.liked = !post.liked;
    post.likes += post.liked ? 1 : -1;
    render();
    return;
  }
  if (reply) {
    const box = feed.querySelector(`.reply-box[data-for="${reply.dataset.reply}"]`);
    box.hidden = !box.hidden;
    if (!box.hidden) box.querySelector("input").focus();
  }
});

feed.addEventListener("submit", (event) => {
  const form = event.target.closest(".reply-box");
  if (!form) return;
  event.preventDefault();
  const input = form.querySelector("input");
  const text = input.value.trim();
  if (!text) return;
  const post = currentBoard().posts.find((item) => item.id === form.dataset.for);
  post.replies.push({ name: speaking().name, avatar: speaking().avatar, alias: state.active, mine: true, text });
  render();
});

document.querySelector("#viewer-close").addEventListener("click", () => viewer.close());
viewer.addEventListener("click", (event) => {
  if (event.target === viewer) viewer.close();
});

if (state.aliases[0].name) showHome();
else openGate(false);
