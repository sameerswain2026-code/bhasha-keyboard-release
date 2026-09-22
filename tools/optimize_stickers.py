from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
sticker_dir = root / 'assets' / 'stickers'
for source in sorted(sticker_dir.glob('*.png')):
    target = source.with_suffix('.webp')
    image = Image.open(source)
    image.save(target, 'WEBP', lossless=True, method=6)
    source.unlink()
    for path in (root / 'lib').rglob('*.dart'):
        text = path.read_text()
        updated = text.replace(f'assets/stickers/{source.name}', f'assets/stickers/{target.name}')
        if updated != text:
            path.write_text(updated)
print('optimized', len(list(sticker_dir.glob('*.webp'))), 'stickers')
