import { createRoot } from "react-dom/client";
import Install from "./InstallPage";
import { initTheme } from "./theme";
import "./index.css";

initTheme();
createRoot(document.getElementById("root")!).render(<Install />);
