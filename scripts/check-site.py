"""Validate the built portfolio and its local links without network dependencies."""

import sys
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit


class Page(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids = set()
        self.links = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if "id" in attrs:
            self.ids.add(attrs["id"])
        for attr in ("href", "src"):
            if attrs.get(attr):
                self.links.append(attrs[attr])


def check(root):
    index = root / "index.html"
    assert index.is_file(), "Missing generated index.html"
    html = index.read_text(encoding="utf-8")
    assert "{{" not in html, "Unrendered Hugo template in output"
    page = Page()
    page.feed(html)
    assert {"work", "about", "contact"} <= page.ids, "Missing portfolio sections"
    for link in page.links:
        url = urlsplit(link)
        if url.scheme or url.netloc:
            continue
        if url.path:
            target = root / unquote(url.path).lstrip("/")
            assert target.is_file(), f"Missing local asset: {link}"
        elif url.fragment:
            assert unquote(url.fragment) in page.ids, f"Missing anchor: {link}"
    print(f"Site checks passed: {len(page.links)} links/assets inspected.")


if __name__ == "__main__":
    check(Path(sys.argv[1] if len(sys.argv) > 1 else "public"))
