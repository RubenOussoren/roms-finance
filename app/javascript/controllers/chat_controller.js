import { Controller } from "@hotwired/stimulus";

const SLASH_COMMANDS = [
  { command: "/report spending", description: "Generate spending report", text: "Generate a spending report for me" },
  { command: "/report networth", description: "Generate net worth report", text: "Generate a net worth report for me" },
  { command: "/report tax", description: "Generate tax report", text: "Generate a tax report for me" },
  { command: "/report investment", description: "Generate investment report", text: "Generate an investment report for me" },
  { command: "/summary", description: "Get financial summary", text: "Give me a summary of my finances" },
  { command: "/holdings", description: "Show investment holdings", text: "Show me my investment holdings" },
  { command: "/budget", description: "Show budget vs actual", text: "Show me my budget vs actual spending" },
];

export default class extends Controller {
  static targets = ["messages", "form", "input", "commandMenu"];
  #boundHandleKeyboard;
  #selectedIndex = -1;

  connect() {
    this.#configureAutoScroll();
    this.#boundHandleKeyboard = this.#handleKeyboardShortcut.bind(this);
    document.addEventListener("keydown", this.#boundHandleKeyboard);
  }

  disconnect() {
    if (this.messagesObserver) {
      this.messagesObserver.disconnect();
    }
    document.removeEventListener("keydown", this.#boundHandleKeyboard);
  }

  autoResize() {
    const input = this.inputTarget;
    const lineHeight = 20; // text-sm line-height (14px * 1.429 ≈ 20px)
    const maxLines = 3; // 3 lines = 60px total

    input.style.height = "auto";
    input.style.height = `${Math.min(input.scrollHeight, lineHeight * maxLines)}px`;
    input.style.overflowY =
      input.scrollHeight > lineHeight * maxLines ? "auto" : "hidden";
  }

  handleInput() {
    this.autoResize();
    this.#updateCommandMenu();
  }

  submitSampleQuestion(e) {
    this.inputTarget.value = e.target.dataset.chatQuestionParam;

    setTimeout(() => {
      this.formTarget.requestSubmit();
    }, 200);
  }

  clearInput() {
    this.inputTarget.value = "";
    this.inputTarget.style.height = "auto";
    this.inputTarget.focus();
    this.#hideCommandMenu();
  }

  // Newlines require shift+enter, otherwise submit the form (same functionality as ChatGPT and others)
  handleInputKeyDown(e) {
    if (this.#isCommandMenuVisible()) {
      if (e.key === "ArrowDown") {
        e.preventDefault();
        this.#navigateMenu(1);
        return;
      }
      if (e.key === "ArrowUp") {
        e.preventDefault();
        this.#navigateMenu(-1);
        return;
      }
      if (e.key === "Enter" && !e.shiftKey) {
        e.preventDefault();
        if (this.#selectedIndex >= 0) {
          this.#selectCommand(this.#selectedIndex);
        }
        return;
      }
      if (e.key === "Escape") {
        e.preventDefault();
        this.#hideCommandMenu();
        return;
      }
    }

    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      this.formTarget.requestSubmit();
    }
  }

  selectCommand(e) {
    const index = Number.parseInt(e.currentTarget.dataset.index, 10);
    this.#selectCommand(index);
  }

  #updateCommandMenu() {
    const value = this.inputTarget.value;

    if (!value.startsWith("/")) {
      this.#hideCommandMenu();
      return;
    }

    const query = value.toLowerCase();
    const matches = SLASH_COMMANDS.filter(cmd =>
      cmd.command.startsWith(query) || cmd.description.toLowerCase().includes(query.slice(1))
    );

    if (matches.length === 0) {
      this.#hideCommandMenu();
      return;
    }

    this.#selectedIndex = 0;
    this.#renderCommandMenu(matches);
  }

  #renderCommandMenu(commands) {
    if (!this.hasCommandMenuTarget) return;

    const menu = this.commandMenuTarget;
    menu.replaceChildren();

    commands.forEach((cmd, i) => {
      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = `w-full text-left px-3 py-2 text-sm hover:bg-container-hover rounded ${i === this.#selectedIndex ? "bg-container-hover" : ""}`;
      btn.dataset.action = "click->chat#selectCommand";
      btn.dataset.index = i;
      btn.dataset.commandText = cmd.text;

      const cmdSpan = document.createElement("span");
      cmdSpan.className = "font-medium text-primary";
      cmdSpan.textContent = cmd.command;

      const descSpan = document.createElement("span");
      descSpan.className = "text-secondary ml-2";
      descSpan.textContent = cmd.description;

      btn.append(cmdSpan, descSpan);
      menu.append(btn);
    });

    menu.classList.remove("hidden");
    this._currentCommands = commands;
  }

  #hideCommandMenu() {
    if (!this.hasCommandMenuTarget) return;
    this.commandMenuTarget.classList.add("hidden");
    this.commandMenuTarget.innerHTML = "";
    this.#selectedIndex = -1;
    this._currentCommands = null;
  }

  #isCommandMenuVisible() {
    return this.hasCommandMenuTarget && !this.commandMenuTarget.classList.contains("hidden");
  }

  #navigateMenu(direction) {
    if (!this._currentCommands) return;
    const len = this._currentCommands.length;
    this.#selectedIndex = (this.#selectedIndex + direction + len) % len;
    this.#renderCommandMenu(this._currentCommands);
  }

  #selectCommand(index) {
    const commands = this._currentCommands;
    if (!commands || !commands[index]) return;

    this.inputTarget.value = commands[index].text;
    this.#hideCommandMenu();
    this.autoResize();
    this.formTarget.requestSubmit();
  }

  #configureAutoScroll() {
    this.messagesObserver = new MutationObserver((_mutations) => {
      if (this.hasMessagesTarget) {
        this.#scrollToBottom();
      }
    });

    // Listen to entire sidebar for changes, always try to scroll to the bottom
    this.messagesObserver.observe(this.element, {
      childList: true,
      subtree: true,
    });
  }

  #scrollToBottom = () => {
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight;
  };

  #handleKeyboardShortcut(e) {
    if ((e.ctrlKey || e.metaKey) && e.key === "/") {
      e.preventDefault();
      if (this.hasInputTarget) {
        this.inputTarget.focus();
      }
    }
  }
}
