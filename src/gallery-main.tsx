import { createRoot } from "react-dom/client";
import Gallery from "./Gallery";
import { initTheme } from "./theme";
import "./index.css";

initTheme();
createRoot(document.getElementById("root")!).render(<Gallery />);
