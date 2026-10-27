# Prompt bộ minh họa C — 26/10/2026

Công cụ: imagegen tích hợp, không dùng CLI hoặc API key. Tham chiếu là board gốc, không cắt ảnh từ board đưa vào sản phẩm. Sau tạo chỉ thu nhỏ để đóng gói và giữ alpha.

## Bò — assets/illustrations/cow.png

Use case: illustration-story. Create ONE new production PNG asset on a genuinely transparent background for the Smart Farm mobile app. The provided image is a STYLE REFERENCE only: match the cute cow stickers in the FIRST and SECOND phone screens exactly in visual character. Output ONLY ONE cow sticker, no phone/UI/text. Cute big rounded cow head, tiny compact body barely visible, three-quarter facing right, ivory coat with a few dark chocolate patches, large peach-pink muzzle with two tiny nostrils, tiny black oval eyes, short horns and large round ears, friendly expression. Thick smooth dark cocoa outline, flat pastel fills with very subtle shading, illustrated children's app style, green grass/leaf tufts at the bottom. Large head occupies 65% of the figure, fills square canvas nearly edge to edge with 5% clear padding. NO realistic anatomy, no visible udder, no long legs, no white sticker border, no 3D, no photographic texture. Transparent alpha outside animal and small grass tufts. This replaces the overly realistic cow currently used by the app.

## Heo, dê, gà — assets/illustrations/pig.png, goat.png, chicken.png

Một lượt imagegen cho từng con, dùng board `nhom-02.png` và PNG bò mới làm tham chiếu. Prompt chung:

Use case: illustration-story. Create ONE new standalone square transparent PNG sticker for Smart Farm. Input image 1 is a style reference UI board, not the output. Input image 2 is the new cow sticker to match as the same illustrated family. SUBJECT. Flat pastel fills with minimal soft shading, thick smooth dark chocolate outline, children's app illustration, head dominant, close-up not realistic anatomy, friendly and simple at 48 pixels. Object occupies about 90% of square with clear margin all around. No UI, no words, no white sticker stroke, no border, no background rectangle. Genuine transparent alpha outside the animal and grass.

SUBJECT cho từng lượt:

- One peach-pink piglet, very large round head, little floppy ears, big soft pink oval snout with two nostrils, small black oval eyes, happy gentle expression, short compact body, small green grass tufts around its feet. Match the PIG in the first two phone screens of the reference.
- One ivory baby goat, very large round head, two little tan horns, floppy ears, tiny beard, little cocoa eyes, small orange-pink muzzle, short compact body, little grass tufts. Match the GOAT in the first two phone screens of the reference.
- One ivory-white cute hen, very large rounded head and compact body, red-orange comb, tiny orange beak, small oval black eyes, raised tail, yellow feet among small green grass tufts. Match the HEN on the third screen in the original concept set, with the same dark cocoa outline and flat pastel style as the supplied cow.

## Phong cảnh — assets/illustrations/farm-banner.png

Use case: illustration-story. Create a new landscape banner asset ONLY for Smart Farm mobile UI, wide 3:1 aspect ratio. The attached UI concept is a STYLE and composition reference only, especially the landscape banner under the user card on the first phone. Match that gentle flat pastel children's illustration: small coral-red barn with white trim on the LEFT, cream picket fence extending horizontally, rounded green trees and light mint rolling hills, soft sky blue rounded clouds, small warm yellow sun on the upper right. Leave the RIGHT third mostly open green landscape for a cow sticker to be overlaid in code. White/very pale warm cream (#FFFCF5) sky at upper edge so it blends into the app background. Soft rounded shapes, very delicate outlines for scenery; no heavy dark strokes in this landscape. No animals, no text, no phone, no UI elements. Minimal details, calm cheerful warm pastel palette, crisp clean raster illustration. The entire output is a wide landscape illustration, not a mockup.

## Chuồng — assets/illustrations/barn.png

Use case: illustration-story. One small coral-red farm barn icon for a cute children's farm app. Square PNG with real transparent background. A friendly barn in front view with rounded gambrel roof, white cream frame and cross-braced doors, tiny upper window, small grass and leaf tufts at bottom. Simple flat pastel fills, short warm cocoa outline, same polished flat pastel aesthetic as the supplied cow sticker. Fill 86% of square, 7% transparent margin. No animals, no text, no sticker border, no UI, no scenery background.
