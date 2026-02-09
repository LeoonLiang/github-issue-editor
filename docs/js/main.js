// 平滑滚动
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
        e.preventDefault();
        const target = document.querySelector(this.getAttribute('href'));
        if (target) {
            target.scrollIntoView({
                behavior: 'smooth',
                block: 'start'
            });
        }
    });
});

// 添加滚动动画效果
const observerOptions = {
    threshold: 0.1,
    rootMargin: '0px 0px -100px 0px'
};

const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
        if (entry.isIntersecting) {
            entry.target.style.opacity = '1';
            entry.target.style.transform = 'translateY(0)';
        }
    });
}, observerOptions);

// 观察所有需要动画的元素
document.addEventListener('DOMContentLoaded', () => {
    const animatedElements = document.querySelectorAll('.feature-card, .article-card');
    animatedElements.forEach(el => {
        el.style.opacity = '0';
        el.style.transform = 'translateY(20px)';
        el.style.transition = 'opacity 0.6s ease, transform 0.6s ease';
        observer.observe(el);
    });

    // 主题切换功能
    const themeToggle = document.getElementById('themeToggle');
    const themeIcon = document.getElementById('themeIcon');
    const phoneScreen = document.getElementById('phoneScreen');

    // 从localStorage读取主题
    const savedTheme = localStorage.getItem('theme') || 'light';
    document.documentElement.setAttribute('data-theme', savedTheme);
    updateThemeIcon(savedTheme);

    if (themeToggle) {
        themeToggle.addEventListener('click', () => {
            const currentTheme = document.documentElement.getAttribute('data-theme');
            const newTheme = currentTheme === 'dark' ? 'light' : 'dark';

            document.documentElement.setAttribute('data-theme', newTheme);
            localStorage.setItem('theme', newTheme);
            updateThemeIcon(newTheme);

            // 通知iframe内的页面切换主题
            if (phoneScreen && phoneScreen.contentWindow) {
                phoneScreen.contentWindow.postMessage({ type: 'theme-change', theme: newTheme }, '*');
            }
        });
    }

    function updateThemeIcon(theme) {
        if (themeIcon) {
            themeIcon.setAttribute('data-icon', theme === 'dark' ? 'mdi:weather-night' : 'mdi:weather-sunny');
        }
    }

    // 移动端截图轮播
    const screenshots = ['images/list.jpg', 'images/publish.jpg', 'images/setting.jpg'];
    const screenshotImage = document.getElementById('screenshotImage');
    const screenshotCarousel = document.querySelector('.screenshot-carousel');
    const dots = document.querySelectorAll('.carousel-dots .dot');
    let currentIndex = 0;
    let autoPlayInterval;
    let touchStartX = 0;
    let touchEndX = 0;

    function showScreenshot(index) {
        if (screenshotImage) {
            currentIndex = index;
            screenshotImage.src = screenshots[index];

            // 更新dots状态
            dots.forEach((dot, i) => {
                dot.classList.toggle('active', i === index);
            });
        }
    }

    function startAutoPlay() {
        autoPlayInterval = setInterval(() => {
            currentIndex = (currentIndex + 1) % screenshots.length;
            showScreenshot(currentIndex);
        }, 3000); // 每3秒切换
    }

    function stopAutoPlay() {
        if (autoPlayInterval) {
            clearInterval(autoPlayInterval);
        }
    }

    function handleSwipe() {
        const swipeThreshold = 50; // 最小滑动距离
        const diff = touchStartX - touchEndX;

        if (Math.abs(diff) > swipeThreshold) {
            stopAutoPlay();

            if (diff > 0) {
                // 向左滑动 - 下一张
                currentIndex = (currentIndex + 1) % screenshots.length;
            } else {
                // 向右滑动 - 上一张
                currentIndex = (currentIndex - 1 + screenshots.length) % screenshots.length;
            }

            showScreenshot(currentIndex);
            startAutoPlay();
        }
    }

    // 触摸事件
    if (screenshotCarousel) {
        screenshotCarousel.addEventListener('touchstart', (e) => {
            touchStartX = e.changedTouches[0].screenX;
        }, { passive: true });

        screenshotCarousel.addEventListener('touchend', (e) => {
            touchEndX = e.changedTouches[0].screenX;
            handleSwipe();
        }, { passive: true });

        // 鼠标拖拽事件（桌面端也可用）
        let mouseDown = false;
        screenshotCarousel.addEventListener('mousedown', (e) => {
            mouseDown = true;
            touchStartX = e.screenX;
        });

        screenshotCarousel.addEventListener('mouseup', (e) => {
            if (mouseDown) {
                touchEndX = e.screenX;
                handleSwipe();
                mouseDown = false;
            }
        });

        screenshotCarousel.addEventListener('mouseleave', () => {
            mouseDown = false;
        });
    }

    // Dots点击事件
    dots.forEach((dot, index) => {
        dot.addEventListener('click', () => {
            stopAutoPlay();
            showScreenshot(index);
            startAutoPlay();
        });
    });

    // 只在移动端自动播放
    if (window.innerWidth <= 768) {
        startAutoPlay();
    }

    // 窗口大小改变时重新判断
    window.addEventListener('resize', () => {
        if (window.innerWidth <= 768) {
            startAutoPlay();
        } else {
            stopAutoPlay();
        }
    });
});
