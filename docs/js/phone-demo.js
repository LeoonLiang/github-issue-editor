// 手机演示交互
document.addEventListener('DOMContentLoaded', () => {
    const phoneScreen = document.getElementById('phoneScreen');
    const featureBtns = document.querySelectorAll('.feature-btn');

    // 功能按钮点击事件
    featureBtns.forEach(btn => {
        btn.addEventListener('click', () => {
            // 移除所有活动状态
            featureBtns.forEach(b => b.classList.remove('active'));

            // 添加当前活动状态
            btn.classList.add('active');

            // 获取要显示的屏幕
            const screen = btn.dataset.screen;

            // 添加淡出效果
            phoneScreen.style.opacity = '0';
            phoneScreen.style.transform = 'scale(0.95)';

            // 切换屏幕
            setTimeout(() => {
                phoneScreen.src = `mock-screens/${screen}.html`;

                // 添加淡入效果
                setTimeout(() => {
                    phoneScreen.style.opacity = '1';
                    phoneScreen.style.transform = 'scale(1)';
                }, 50);
            }, 200);
        });
    });

    // 添加过渡效果
    phoneScreen.style.transition = 'opacity 0.2s ease, transform 0.2s ease';

    // 手机模拟器 3D 效果
    const phoneMock = document.getElementById('phoneMock');

    phoneMock.addEventListener('mousemove', (e) => {
        const rect = phoneMock.getBoundingClientRect();
        const x = e.clientX - rect.left;
        const y = e.clientY - rect.top;

        const centerX = rect.width / 2;
        const centerY = rect.height / 2;

        const rotateX = (y - centerY) / 20;
        const rotateY = (centerX - x) / 20;

        phoneMock.style.transform = `perspective(1000px) rotateX(${rotateX}deg) rotateY(${rotateY}deg) scale(1.02)`;
    });

    phoneMock.addEventListener('mouseleave', () => {
        phoneMock.style.transform = 'perspective(1000px) rotateX(0) rotateY(0) scale(1)';
    });

    // 添加过渡效果
    phoneMock.style.transition = 'transform 0.3s ease';
});
