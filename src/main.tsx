import { createRoot } from "react-dom/client";
import Home from "./Home";
import { initTheme } from "./theme";
import "./index.css";

initTheme();
createRoot(document.getElementById("root")!).render(<Home />);
