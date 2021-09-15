import { Selector } from "testcafe";

export class Homepage {
  constructor() {
    this.mainTitle = Selector('h1');
    this.contentLinks = Selector('div.dialog-off-canvas-main-canvas a');
  }
}

export default Homepage = new Homepage();
